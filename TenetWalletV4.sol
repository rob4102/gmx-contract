// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOrderBook {
    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;

    function updateDecreaseOrder(
        uint256 _orderIndex,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external;
}

// Interface for the Position Router
interface IPositionRouter {
    function createIncreasePosition(
        address[] memory path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        bytes32 referralCode,
        address callbackTarget
    ) external payable;

    function createDecreasePosition(
        address[] memory path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        bool withdrawETH,
        address callbackTarget
    ) external payable;
}

interface IRouter {
    function approvePlugin(address _plugin) external;

    function swap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver
    ) external;
}

contract TenetWalletv4 {
    address public owner1;
    address public owner2;
    bool public owner1Approval;
    bool public owner2Approval;
    uint256 public approvalTimestamp;
    mapping(address => uint256) public ownerBalance;
    string public ContractName;

    // Define the token constants
    address public constant USDC_ADDRESS =
        0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public constant AVAX_ADDRESS = address(0); // Address(0) for native AVAX
    address public constant WAVAX_ADDRESS =
        0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // WAVAX
    address public constant WETH_ADDRESS =
        0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB; // WETH Address
    address public constant BTC_ADDRESS =
        0x152b9d0FdC40C096757F570A51E494bd4b943E50; // btc
    // Hard-coded router and position router addresses
    address public constant ROUTER_ADDRESS =
        0x5F719c2F1095F7B9fc68a68e35B51194f4b6abe8;
    address public constant POSITION_ROUTER_ADDRESS =
        0xffF6D276Bc37c61A23f06410Dce4A400f66420f8;
    address public constant ORDERBOOK_ADDRESS =
        0x4296e307f108B2f583FF2F7B7270ee7831574Ae5;

    // Mapping to track approved plugins for each owner
    mapping(address => mapping(address => bool)) public approvedPlugins;

    struct WithdrawalRequest {
        uint256 amount;
        uint256 timestamp;
        bool executed;
        address requester;
    }

    WithdrawalRequest public pendingWithdrawal;
    mapping(address => WithdrawalRequest) public pendingTokenWithdrawals;

    event Deposit(address indexed depositor, uint256 amount);
    event TokenDeposit(address indexed token, uint256 amount);
    event WithdrawalRequested(uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed owner, uint256 amount);
    event TokenWithdrawalRequested(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    event TokenWithdrawal(
        address indexed token,
        address indexed owner,
        uint256 amount
    );
    event ApprovalGranted(address indexed owner, bool approved);

    constructor(
        address _owner1,
        address _owner2,
        string memory _contractName
    ) {
        require(
            _owner1 != address(0) && _owner2 != address(0),
            "Owners cannot be zero address"
        );
        ContractName = _contractName;
        owner1 = _owner1;
        owner2 = _owner2;
    }

    modifier onlyOwners() {
        require(
            msg.sender == owner1 || msg.sender == owner2,
            "Only an owner can call this function."
        );
        _;
    }

    function approveTransfer(bool approval) public onlyOwners {
        if (msg.sender == owner1) {
            owner1Approval = approval;
        } else if (msg.sender == owner2) {
            owner2Approval = approval;
        }

        bool bothApproved = owner1Approval && owner2Approval;

        if (bothApproved) {
            approvalTimestamp = block.timestamp;
        }

        emit ApprovalGranted(msg.sender, approval);
    }

    // Fallback function to receive ether and emit a deposit event
    receive() external payable {
        uint256 ownerShare = msg.value / 2;
        ownerBalance[owner1] += ownerShare;
        ownerBalance[owner2] += ownerShare;
        emit Deposit(msg.sender, msg.value);
    }

    function resetApprovals() internal {
        owner1Approval = false;
        owner2Approval = false;
        approvalTimestamp = 0;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0.");
        uint256 depositAmount = msg.value;
        uint256 ownerShare = depositAmount / 2;

        ownerBalance[owner1] += ownerShare;
        ownerBalance[owner2] += ownerShare;

        emit Deposit(msg.sender, depositAmount);
    }

    function depositToken(address token, uint256 amount) public {
        require(
            token == USDC_ADDRESS ||
                token == WAVAX_ADDRESS ||
                token == WETH_ADDRESS ||
                token == BTC_ADDRESS,
            "Token not accepted."
        );
        require(amount > 0, "Amount must be greater than 0.");

        // Using SafeERC20 and IERC20 interface for the transfer
        SafeERC20.safeTransferFrom(
            IERC20(token),
            msg.sender,
            address(this),
            amount
        );

        uint256 ownerShare = amount / 2;
        ownerBalance[owner1] += ownerShare;
        ownerBalance[owner2] += ownerShare;

        emit TokenDeposit(token, amount);
    }

    function requestWithdrawal(uint256 amount) public onlyOwners {
        require(amount <= address(this).balance, "Insufficient balance.");
        require(
            pendingWithdrawal.amount == 0,
            "A withdrawal is already pending."
        );

        pendingWithdrawal = WithdrawalRequest({
            amount: amount,
            timestamp: block.timestamp,
            executed: false,
            requester: msg.sender
        });

        emit WithdrawalRequested(amount, block.timestamp);
    }

    function executeWithdrawal() public onlyOwners {
        require(
            owner1Approval && owner2Approval,
            "Both owners must approve the withdrawal."
        );
        require(
            block.timestamp <= approvalTimestamp + 1 hours,
            "Approval expired."
        );
        require(!pendingWithdrawal.executed, "Withdrawal already executed.");
        require(pendingWithdrawal.amount > 0, "No withdrawal pending.");
        require(
            pendingWithdrawal.requester != msg.sender,
            "Requester cannot execute the withdrawal."
        );

        uint256 share = pendingWithdrawal.amount / 2;
        ownerBalance[owner1] -= share;
        ownerBalance[owner2] -= share;

        // Reset pending withdrawal after execution
        WithdrawalRequest memory executedWithdrawal = pendingWithdrawal;
        pendingWithdrawal = WithdrawalRequest(0, 0, false, address(0));
        resetApprovals();

        payable(owner1).transfer(share);
        payable(owner2).transfer(share);

        emit Withdrawal(msg.sender, executedWithdrawal.amount);
    }

    function executeTokenWithdrawal(address token) public onlyOwners {
        require(
            owner1Approval && owner2Approval,
            "Both owners must approve the withdrawal."
        );
        require(
            block.timestamp <= approvalTimestamp + 1 hours,
            "Approval expired."
        );
        require(
            !pendingTokenWithdrawals[token].executed,
            "Token withdrawal already executed."
        );
        require(
            pendingTokenWithdrawals[token].amount > 0,
            "No token withdrawal pending."
        );
        require(
            pendingTokenWithdrawals[token].requester != msg.sender,
            "Requester cannot execute the withdrawal."
        );

        uint256 share = pendingTokenWithdrawals[token].amount / 2;

        // Reset pending token withdrawal after execution
        WithdrawalRequest memory executedWithdrawal = pendingTokenWithdrawals[
            token
        ];
        pendingTokenWithdrawals[token] = WithdrawalRequest(
            0,
            0,
            false,
            address(0)
        );
        resetApprovals();

        require(
            IERC20(token).transfer(owner1, share),
            "Token transfer to owner1 failed."
        );
        require(
            IERC20(token).transfer(owner2, share),
            "Token transfer to owner2 failed."
        );

        emit TokenWithdrawal(token, msg.sender, executedWithdrawal.amount);
    }

    function requestTokenWithdrawal(address token, uint256 amount)
        public
        onlyOwners
    {
        require(
            token == USDC_ADDRESS ||
                token == WAVAX_ADDRESS ||
                token == WETH_ADDRESS ||
                token == BTC_ADDRESS,
            "Token not accepted."
        );
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient token balance."
        );
        require(
            pendingTokenWithdrawals[token].amount == 0,
            "A token withdrawal is already pending."
        );

        pendingTokenWithdrawals[token] = WithdrawalRequest({
            amount: amount,
            timestamp: block.timestamp,
            executed: false,
            requester: msg.sender
        });

        emit TokenWithdrawalRequested(token, amount, block.timestamp);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getOwner1Balance() public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](3);
        balances[0] = address(this).balance / 2;
        balances[1] = IERC20(USDC_ADDRESS).balanceOf(address(this)) / 2;
        balances[2] = IERC20(WAVAX_ADDRESS).balanceOf(address(this)) / 2;
        balances[3] = IERC20(WETH_ADDRESS).balanceOf(address(this)) / 2;
        balances[4] = IERC20(BTC_ADDRESS).balanceOf(address(this)) / 2;
        return balances;
    }

    function getOwner2Balance() public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](3);
        balances[0] = address(this).balance / 2;
        balances[1] = IERC20(USDC_ADDRESS).balanceOf(address(this)) / 2;
        balances[2] = IERC20(WAVAX_ADDRESS).balanceOf(address(this)) / 2;
        balances[3] = IERC20(WETH_ADDRESS).balanceOf(address(this)) / 2;
        balances[4] = IERC20(BTC_ADDRESS).balanceOf(address(this)) / 2;
        return balances;
    }

    // Function to call createIncreasePosition on a position router contract
    function createIncreasePosition(
        address[] memory path, // Path for token swaps
        address indexToken, // Token to be indexed
        uint256 amountIn, // Amount of tokens to increase position
        uint256 minOut, // Minimum acceptable output amount
        uint256 sizeDelta, // Change in position size
        bool isLong, // Indicator if the position is long
        uint256 acceptablePrice, // Acceptable price for the position
        uint256 executionFee, // Fee for executing the position increase
        bytes32 referralCode, // Referral code for tracking
        address callbackTarget // Callback target address
    ) public payable onlyOwners {
        require(
            isPluginApproved(address(this), POSITION_ROUTER_ADDRESS),
            "Plugin not approved"
        );

        IPositionRouter(POSITION_ROUTER_ADDRESS).createIncreasePosition{
            value: msg.value
        }(
            path,
            indexToken,
            amountIn,
            minOut,
            sizeDelta,
            isLong,
            acceptablePrice,
            executionFee,
            referralCode,
            callbackTarget
        );
    }

    // Function to call createDecreasePosition on a position router contract
    function createDecreasePosition(
        address[] memory path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        bool withdrawETH,
        address callbackTarget
    ) public payable onlyOwners {
        require(
            isPluginApproved(address(this), POSITION_ROUTER_ADDRESS),
            "Plugin not approved"
        );

        address receiver = address(this);

        IPositionRouter(POSITION_ROUTER_ADDRESS).createDecreasePosition{
            value: msg.value
        }(
            path,
            indexToken,
            collateralDelta,
            sizeDelta,
            isLong,
            receiver,
            acceptablePrice,
            minOut,
            executionFee,
            withdrawETH,
            callbackTarget
        );
    }

    // Function to approve the PositionRouter as a plugin
    function approvePositionRouter() public onlyOwners {
        approvedPlugins[address(this)][POSITION_ROUTER_ADDRESS] = true;
        IRouter(ROUTER_ADDRESS).approvePlugin(POSITION_ROUTER_ADDRESS);
    }

    // Function to check if a plugin is approved
    function isPluginApproved(address user, address plugin)
        public
        view
        returns (bool)
    {
        return approvedPlugins[user][plugin];
    }

    // Function to approve USDC spending by the PositionRouter
    function approveUSDCSpending(uint256 amount) public onlyOwners {
        require(amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(USDC_ADDRESS).approve(ROUTER_ADDRESS, amount),
            "Approval failed."
        );
    }

    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) public payable onlyOwners {
        // Ensure that the contract has enough ETH to cover the minimum execution fee
        require(msg.value > 0, "Insufficient ETH for execution fee.");
        // Call the external OrderBook's createDecreaseOrder function
        IOrderBook(ORDERBOOK_ADDRESS).createDecreaseOrder{value: msg.value}(
            _indexToken,
            _sizeDelta,
            _collateralToken,
            _collateralDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }

    function swapTokens(
        address[] memory _path, // Path for the swap, starting with input token and ending with output token
        uint256 _amountIn, // Amount of input tokens to swap
        uint256 _minOut // Minimum amount of output tokens to receive
    )
        public
        //address _receiver // Address to receive the output tokens
        onlyOwners
    {
        // Use IERC20 to check the current allowance
        uint256 currentAllowance = IERC20(_path[0]).allowance(
            address(this),
            ROUTER_ADDRESS
        );

        // If the current allowance is less than the amount needed, reset it to zero, then approve the required amount
        if (currentAllowance < _amountIn) {
            // Reset the allowance to zero first
            require(
                IERC20(_path[0]).approve(ROUTER_ADDRESS, 0),
                "Resetting token approval to zero failed."
            );

            // Approve the required amount
            require(
                IERC20(_path[0]).approve(ROUTER_ADDRESS, _amountIn),
                "Token approval failed."
            );
        }

        // Call the Router's swap function
        IRouter(ROUTER_ADDRESS).swap(_path, _amountIn, _minOut, address(this));
    }
}

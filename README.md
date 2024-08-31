# Tenet Wallet v4

## Overview

`Tenet Wallet v4` is a Solidity smart contract designed to manage a dual-ownership wallet with built-in support for interacting with DeFi protocols. The contract allows two owners to jointly manage deposits, withdrawals, and token swaps. It integrates with GMX contracts; `OrderBook`, `PositionRouter`, and `Router` to create and manage trading positions, execute swaps, and approve token spending.

## Features

- **Dual Ownership**: The contract is managed by two owners, both of whom must approve certain actions such as withdrawals and position management.
- **Multi-Token Support**: Supports deposits and withdrawals of AVAX, USDC, WAVAX, WETH, and BTC.
- **DeFi Integration**: Interacts with external DeFi protocols to manage trading positions and execute token swaps.
- **Plugin Approval**: Supports plugin approval for interaction with DeFi contracts.
- **Event Emissions**: Emits events for all major actions such as deposits, withdrawals, and approvals.

## Contract Functions

### Constructor

`solidity
constructor(address _owner1, address _owner2)

### Initializes the Contract
The contract is initialized with two owners. Both owners must be non-zero addresses.

### Ownership Functions
- **`approveTransfer(bool approval)`**: Owners can approve or disapprove transfers.
- **`resetApprovals()`**: Resets approvals for both owners.

### Deposit Functions
- **`deposit()`**: Allows owners to deposit native AVAX into the contract. The deposited amount is split equally between the two owners.
- **`depositToken(address token, uint256 amount)`**: Allows owners to deposit ERC-20 tokens into the contract.

### Withdrawal Functions
- **`requestWithdrawal(uint256 amount)`**: Requests a withdrawal of native AVAX from the contract.
- **`executeWithdrawal()`**: Executes the withdrawal after both owners approve.
- **`requestTokenWithdrawal(address token, uint256 amount)`**: Requests a withdrawal of ERC-20 tokens from the contract.
- **`executeTokenWithdrawal(address token)`**: Executes the token withdrawal after both owners approve.

### Position Management
- **`createIncreasePosition(...)`**: Calls `createIncreasePosition` on the `PositionRouter` contract to increase a trading position.
- **`createDecreasePosition(...)`**: Calls `createDecreasePosition` on the `PositionRouter` contract to decrease a trading position.
- **`createDecreaseOrder(...)`**: Calls `createDecreaseOrder` on the `OrderBook` contract to create a decrease order.
- **`updateDecreaseOrder(...)`**: Calls `updateDecreaseOrder` on the `OrderBook` contract to update an existing decrease order.
- **`cancelDecreaseOrder(uint256 _orderIndex)`**: Cancels an existing decrease order on the `OrderBook` contract.

### Token Swap
- **`swapTokens(...)`**: Swaps tokens using the `Router` contract, ensuring that the receiver is either one of the owners or the contract itself.

### Utility Functions
- **`approvePositionRouter()`**: Approves the `PositionRouter` as a plugin for token spending.
- **`approveUSDCSpending(uint256 amount)`**: Approves USDC spending by the `PositionRouter`.
- **`isPluginApproved(address user, address plugin)`**: Checks if a plugin is approved for a specific user.
- **`getBalance()`**: Returns the contract's balance of native AVAX.
- **`getTokenBalance(address token)`**: Returns the contract's balance of a specific ERC-20 token.
- **`getOwner1Balance()`**: Returns the token balances allocated to `owner1`.
- **`getOwner2Balance()`**: Returns the token balances allocated to `owner2`.

### Events
- **`Deposit(address indexed depositor, uint256 amount)`**: Emitted when a deposit is made.
- **`TokenDeposit(address indexed token, uint256 amount)`**: Emitted when a token deposit is made.
- **`WithdrawalRequested(uint256 amount, uint256 timestamp)`**: Emitted when a withdrawal is requested.
- **`Withdrawal(address indexed owner, uint256 amount)`**: Emitted when a withdrawal is executed.
- **`TokenWithdrawalRequested(address indexed token, uint256 amount, uint256 timestamp)`**: Emitted when a token withdrawal is requested.
- **`TokenWithdrawal(address indexed token, address indexed owner, uint256 amount)`**: Emitted when a token withdrawal is executed.
- **`ApprovalGranted(address indexed owner, bool approved)`**: Emitted when an owner grants or revokes approval.

### Usage
To use this contract, deploy it with two owner addresses. Owners can then interact with the contract functions to manage funds, create and manage trading positions, and execute token swaps.

## Step-by-Step Explanation of Two-Owner Approval, and Execute Withdrawals Functions

### 1. Approve Transactions
**Function**: `approveTransfer(bool approval)`

**Step-by-Step**:
- **Initiate Approval**: One of the owners calls `approveTransfer` with `true` as the argument to indicate approval.
- **Set Approval Status**: The contract records the approval status for the owner who called the function. If the other owner has also approved, both approval flags are set to `true`.
- **Approval Timestamp**: If both owners have approved, the contract sets an `approvalTimestamp` to mark when both approvals were granted.

**Security Benefit**: This function ensures that both owners must agree on important transactions, preventing unilateral actions by a single owner. The use of a timestamp further ensures that approvals have a time limit, adding a layer of security by preventing stale approvals from being used.

### 2. Request Withdrawals
**Functions**:
- `requestWithdrawal(uint256 amount)` (for native AVAX)
- `requestTokenWithdrawal(address token, uint256 amount)` (for ERC-20 tokens)

**Step-by-Step**:
- **Check Balance**: The contract checks if the requested withdrawal amount is available in the contract.
- **Check for Pending Withdrawals**: The contract ensures that there are no other pending withdrawals. Only one withdrawal request can be active at a time.
- **Create Withdrawal Request**: The contract stores the withdrawal request details (amount, timestamp, requester) in `pendingWithdrawal` or `pendingTokenWithdrawals`, depending on the type of withdrawal.
- **Emit Event**: The contract emits a `WithdrawalRequested` or `TokenWithdrawalRequested` event to log the request.

**Security Benefit**: This function ensures that withdrawal requests are formally logged and must be approved by both owners before being executed, adding a layer of accountability and traceability.

### 3. Two-Owner Approval
**Function**: `approveTransfer(bool approval)` (described earlier)

**Step-by-Step**:
- **Owner 1 Approval**: One owner calls `approveTransfer` to indicate their approval for the pending withdrawal.
- **Owner 2 Approval**: The second owner must also call `approveTransfer` to give their approval.
- **Both Approvals Verified**: The contract verifies that both owners have approved the transaction within a certain time window (e.g., within one hour of the first approval).

**Security Benefit**: Requiring approval from both owners ensures that no single owner can unilaterally withdraw funds, preventing misuse or theft of funds.

### 4. Execute Withdrawals
**Functions**:
- `executeWithdrawal()` (for native AVAX)
- `executeTokenWithdrawal(address token)` (for ERC-20 tokens)

**Step-by-Step**:
- **Check Approvals**: The contract checks that both owners have approved the withdrawal request.
- **Check Approval Expiry**: The contract ensures that the approvals are still valid (i.e., they haven't expired).
- **Verify Non-Requester Execution**: The owner who requested the withdrawal cannot be the one to execute it, ensuring a separation of duties.
- **Perform Withdrawal**: The contract executes the withdrawal by transferring the specified amount of AVAX or tokens to both owners equally.
- **Reset Pending Withdrawals**: The pending withdrawal request is cleared, and the approvals are reset.
- **Emit Event**: A `Withdrawal` or `TokenWithdrawal` event is emitted to log the successful withdrawal.

**Security Benefit**: This process ensures that funds can only be withdrawn after both owners have approved the transaction, and the approvals are time-bound to avoid exploitation. The separation of the request and execution duties among the owners further enhances security by ensuring that no single owner can both request and execute a withdrawal.

### Security Benefits of These Functions

- **Dual Ownership Requirement**: All critical operations, such as withdrawals and approvals, require the consent of both owners. This multi-signature (multi-sig) approach ensures that no single individual has control over the contract, greatly reducing the risk of malicious actions or errors.

- **Time-Limited Approvals**: By tying approvals to a timestamp, the contract ensures that approvals have a limited validity period. This prevents potential security issues where an old approval could be maliciously or accidentally used to withdraw funds.

- **Transparency and Traceability**: All actions are logged via events, making it easy to audit and trace the history of transactions. This provides accountability and helps in detecting any unauthorized actions.

- **Separation of Duties**: The requirement that the requester cannot execute the withdrawal introduces a separation of duties, further preventing any single owner from having too much control over the funds.

- **Prevention of Stale Approvals**: By resetting approvals after each action, the contract prevents previously granted approvals from being reused inappropriately, thereby minimizing the risk of stale approvals being exploited.

### Create Increase Position
**Description**:  
The `createIncreasePosition` function allows the contract to interact with an external `PositionRouter` contract to increase a trading position on behalf of the owners. This function is primarily used to add leverage to an existing position or to initiate a new position with leverage.

**Parameters**:

- **`path`**: An array of addresses representing the token swap path. The first address is the input token, and the last address is the output token.
- **`indexToken`**: The address of the token that will be indexed in the position (e.g., the asset being traded).
- **`amountIn`**: The amount of input tokens to be used to increase the position.
- **`minOut`**: The minimum acceptable output amount after any swaps, to avoid slippage.
- **`sizeDelta`**: The change in the size of the position, which could represent adding more collateral or increasing leverage.
- **`isLong`**: A boolean value indicating whether the position is long (`true`) or short (`false`).
- **`acceptablePrice`**: The maximum acceptable price for increasing the position (for long positions) or the minimum acceptable price (for short positions).
- **`executionFee`**: The fee paid for executing the increase position transaction.
- **`referralCode`**: A referral code used to track referrals associated with this transaction, if any.
- **`callbackTarget`**: An address that will be called back with the result of the transaction, typically used for further processing.

**Access Control**:  
This function can only be called by the owners of the contract, as enforced by the `onlyOwners` modifier.


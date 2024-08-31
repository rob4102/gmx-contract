# Tenet Wallet v4

## Overview

`Tenet Wallet v4` is a Solidity smart contract designed to manage a dual-ownership wallet with built-in support for interacting with DeFi protocols. The contract allows two owners to jointly manage deposits, withdrawals, and token swaps. It integrates with external DeFi contracts such as `OrderBook`, `PositionRouter`, and `Router` to create and manage trading positions, execute swaps, and approve token spending.

## Features

- **Dual Ownership**: The contract is managed by two owners, both of whom must approve certain actions such as withdrawals and position management.
- **Multi-Token Support**: Supports deposits and withdrawals of AVAX, USDC, WAVAX, WETH, and BTC.
- **DeFi Integration**: Interacts with external DeFi protocols to manage trading positions and execute token swaps.
- **Plugin Approval**: Supports plugin approval for interaction with DeFi contracts.
- **Event Emissions**: Emits events for all major actions such as deposits, withdrawals, and approvals.

## Contract Functions

### Constructor

```solidity
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

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

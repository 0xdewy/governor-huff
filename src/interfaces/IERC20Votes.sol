// SPDX-License-Identifier: GPL-3-OR-LATER
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Votes {

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice The standard EIP-20 approval event
    event Approval(address indexed owner, address indexed spender, uint256 amount);


    // Standard ERC20 view fns
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // Standard ERC20 state changing fns
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    // ERC20 Permit
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;


    // ERC20Votes view fns
    function numCheckpoints(address from) view external returns (uint32);
    function checkpoints(address from, uint32 checkpointNum) view external returns (bytes32);
    function delegates(address from) view external returns (address);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonces(address) external returns (uint256);
    function getCurrentVotes(address) external returns (uint96);
    function getPriorVotes(address, uint blockNumber) external returns (uint96);


    // ERC20Votes state changing fns
    function delegate(address delegatee) external;
    // WARNING: Custom getter
    function checkpointVotes(address from, uint32 nCheckpoint) view external returns (uint96);
    function checkpointBlock(address from, uint32 nCheckpoint) view external returns (uint32);

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

}

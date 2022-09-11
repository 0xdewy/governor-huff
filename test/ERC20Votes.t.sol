// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.12;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20Votes} from "../src/interfaces/IERC20Votes.sol";

contract Events {
    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice The standard EIP-20 approval event
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}

/// @author These tests have been adapted from Solmate.
/// The main changes are:
///  - Use forge-std/Test.sol instead of DS-Test+
///  - Instantiate the Huff contract within the tests as opposed to the abstract contract pattern used by Solmate
///  - Using Foundry exclusively so DappTools invariant tests have been removed
///  - Discontinue use of testFail pattern in favor of vm.expectRevert
contract TestERC20Votes is Test, Events {
    error PermitExpired();
    error InvalidSigner();
    error InsufficientFunds();
    error InsufficientAllowance();
    error VoteOverflow();
    error VoteUnderflow();
    error BlockNumberOverflow();
    error SentToZeroAddress();
    error BlockDoesntExist();

    IERC20Votes token;

    address public bob = address(0xb0b);
    address public beef = address(0xbeef);
    address public babe = address(0xbabe); // Holds tokens

    uint256 private supply;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function mine() public {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function reset() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "huffc";
        inputs[1] = "./src/ERC20Votes.huff";
        inputs[2] = "--bytecode";
        bytes memory bytecode = vm.ffi(inputs);
        if (bytecode.length == 0) {
            revert("Could not find bytecode");
        }

        assembly {
            sstore(token.slot, create(0, add(bytecode, 0x20), mload(bytecode)))
        }
        if (address(token) == address(0)) {
            console.logBytes(bytecode);
            revert("Could not deploy address");
        }
    }

    function setUp() public {
        // TODO: debug why HuffDeployer is failing to deploy
        reset();
        // token = IERC20Votes(HuffDeployer.deploy("ERC20Votes"));
        supply = token.totalSupply();
        assertEq(token.balanceOf(address(this)), supply);
        assertEq(supply, 1_000_000e18);
        token.transfer(babe, 10e18);
    }

    function testMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
    }

    function testNonPayable() public {
        vm.deal(address(this), 10 ether);
        // approve
        (bool success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.approve.selector, beef, 1e18)
        );
        assertFalse(success);
        // transfer
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.transfer.selector, beef, 1e18)
        );
        // transferFrom
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(
                token.transferFrom.selector,
                address(this),
                beef,
                1e18
            )
        );
        assertFalse(success);
        // name
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.name.selector, beef, 1e18)
        );
        assertFalse(success);
        // balanceOf
        (success, ) = address(token).call{value: 1 ether}(
            abi.encodeWithSelector(token.balanceOf.selector, beef)
        );
        assertFalse(success);
        // no data
        (success, ) = address(token).call{value: 1 ether}(abi.encode(0x0));
        assertFalse(success);
    }

    function testApprove() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(address(this), beef, 1e18);
        assertTrue(token.approve(beef, 1e18));
        assertEq(token.allowance(address(this), beef), 1e18);
    }

    function testCheckpoints() public {
        token.transfer(bob, 100);

        vm.startPrank(bob);

        // transfer shouldn't create checkpoints
        token.transfer(bob, 1);
        assertEq(token.delegates(bob), address(0));
        assertEq(token.numCheckpoints(bob), 0);

        // delegate to beef creates checkpoint for beef.
        token.delegate(beef);
        assertEq(token.numCheckpoints(beef), 1);
        assertEq(token.numCheckpoints(bob), 0);
        assertEq(token.delegates(bob), beef);
        assertEq(token.checkpointVotes(beef, 0), token.balanceOf(bob));
        assertEq(token.checkpointBlock(beef, 0), block.number);
        bytes32 checkpointPacked = token.checkpoints(beef, 0);

        vm.stopPrank();
    }

    function testTransferEvents() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), beef, 1e18);
        token.transfer(beef, 1e18);
    }

    function testDelegateEvents() public {
        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(address(this), address(0), beef);
        vm.expectEmit(true, false, false, true);
        emit DelegateVotesChanged(beef, 0, token.balanceOf(address(this)));
        token.delegate(beef);
    }

    function testInfiniteApprovalTransferFrom() public {
        uint256 amount = token.balanceOf(babe);
        vm.prank(babe);
        token.approve(address(this), type(uint256).max);
        vm.stopPrank();
        assertTrue(token.transferFrom(babe, beef, amount));
        assertEq(
            token.allowance(babe, address(this)),
            uint256(type(uint96).max)
        );
        assertEq(token.balanceOf(babe), 0);
        assertEq(token.balanceOf(beef), amount);
    }

    function testTransferInsufficientBalance() public {
        vm.expectRevert(InsufficientFunds.selector);
        vm.prank(beef);
        token.transfer(bob, 1.1e18);
        vm.stopPrank();
    }

    function testTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        vm.prank(from);
        token.approve(address(this), 0.9e18);

        vm.expectRevert(InsufficientAllowance.selector);
        token.transferFrom(from, beef, 1e18);
    }

    function testTransferFromInsufficientBalance() public {
        address from = address(0xABCD);
        vm.prank(from);
        token.approve(address(this), 1e19);
        vm.expectRevert(InsufficientFunds.selector);
        token.transferFrom(from, beef, 1e19);
    }

    // Will fail for values between uint96.max -> uint256.max (uint256.max works)
    function testApproveFuzz(address to, uint96 amount) public {
        assertTrue(token.approve(to, amount));
        assertEq(token.allowance(address(this), to), amount);
    }

    function _testTransfer(address to, uint96 amount) internal {
        uint256 fromBefore = token.balanceOf(address(this));
        uint256 toBefore = token.balanceOf(to);
        if (to == address(0)) {
            vm.expectRevert(SentToZeroAddress.selector);
            token.transfer(to, amount);
        } else if (amount > supply) {
            vm.expectRevert(InsufficientFunds.selector);
            token.transfer(to, amount);
        } else {
            assertTrue(token.transfer(to, amount));
            assertEq(token.totalSupply(), supply);
            assertEq(token.balanceOf(to), toBefore + amount);
            assertEq(token.balanceOf(address(this)), fromBefore - amount);
        }
    }

    function _testTransferFrom(
        address from,
        address to,
        uint96 amount
    ) internal {
        uint256 fromBefore = token.balanceOf(from);
        uint256 toBefore = token.balanceOf(to);
        vm.startPrank(from);
        token.approve(address(this), amount);
        vm.stopPrank();
        if (to == address(0)) {
            vm.expectRevert(SentToZeroAddress.selector);
            token.transferFrom(from, to, amount);
        } else if (fromBefore < amount) {
            vm.expectRevert(InsufficientFunds.selector);
            token.transferFrom(from, to, amount);
        } else if (from == to) {
            assertTrue(token.transferFrom(from, to, amount));
            assertEq(token.totalSupply(), supply);
            assertEq(token.balanceOf(to), toBefore, "to.balance not updated");
            assertEq(
                token.balanceOf(from),
                fromBefore,
                "from.balance not updated"
            );
        } else {
            assertTrue(token.transferFrom(from, to, amount));
            assertEq(token.totalSupply(), supply);
            assertEq(
                token.balanceOf(to),
                amount + toBefore,
                "to.balance not updated"
            );
            assertEq(
                token.balanceOf(from),
                fromBefore - amount,
                "from.balance not updated"
            );
        }
    }

    function testTransferFuzz(address to, uint96 amount) public {
        _testTransfer(to, amount);
    }

    function testTransferFromFuzz(
        address from,
        address to,
        uint96 amount
    ) public {
        if (from != address(this) && to != address(this)) {
            _testTransfer(from, amount);

            _testTransferFrom(from, to, amount);
        }
    }

    function testMoveDelegates() public {
        // this => bob
        token.delegate(bob);

        // bob => babe
        vm.startPrank(bob);
        mine();
        // delegate 0 to babe (cant delegate delegated votes)
        token.delegate(babe);
        vm.stopPrank();
        mine();

        // this 
        assertEq(token.getCurrentVotes(address(this)), 0, "this votes off");
        assertEq(token.numCheckpoints(address(this)), 0, "this checkpoints off");
        // bob
        assertEq(token.getCurrentVotes(bob), token.balanceOf(address(this)), "bob votes off");
        assertEq(token.numCheckpoints(bob), 1, "bob checkpoints off");
        // babe (delegating 0 balance doesn't create a checkpoint)
        assertEq(token.getCurrentVotes(babe), 0, "babe votes off");
        assertEq(token.numCheckpoints(babe), 0, "babe checkpoints off");

        // transfer to babe
        token.transfer(babe, 1);
        mine();

        // // babe
        assertEq(token.getCurrentVotes(babe), 0, "2. babe votes off");
        assertEq(token.numCheckpoints(babe), 0, "2. babe checkpoints off");

        // // bob
        assertEq(token.getCurrentVotes(bob), token.balanceOf(address(this)), "2. bob votes off");
        assertEq(token.numCheckpoints(bob), 2, "2. bob checkpoints off");

        // transfer to bob (bob is delegating to babe)
        token.transfer(bob, 1);
        mine();

        // // babe
        assertEq(token.getCurrentVotes(babe), 1, "2. babe votes off");
        assertEq(token.numCheckpoints(babe), 1, "2. babe checkpoints off");

        // // bob
        assertEq(token.getCurrentVotes(bob), token.balanceOf(address(this)), "2. bob votes off");
        assertEq(token.numCheckpoints(bob), 3, "2. bob checkpoints off");

        // babe now delegates to self
        vm.startPrank(babe);
        token.delegate(babe);
        vm.stopPrank();
        assertEq(token.getCurrentVotes(babe), token.balanceOf(babe) + 1);

    }

    function testCurrentVotes() public {
        assertEq(token.getCurrentVotes(address(this)), 0, "Should have 0 votes");
        token.delegate(address(this));
        // mine();
        assertEq(token.numCheckpoints(address(this)), 1, "Should be 1 checkpoint");
        assertEq(token.getCurrentVotes(address(this)), token.balanceOf(address(this)), "Votes dont match balance");
    }

    function testPriorVotes() public {
        token.delegate(address(this));
        mine();
        uint startingVotes = token.getCurrentVotes(address(this));

        token.transfer(babe, 1);
        mine();

        assertEq(token.getCurrentVotes(address(this)), startingVotes - 1);
        assertEq(token.getPriorVotes(address(this), 1), startingVotes);
    }


    function testPermit() public {
        uint96 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, address(0xCAFE), 1e18);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            1,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(
            owner,
            address(0xCAFE),
            1e18,
            block.timestamp + 1,
            v,
            r,
            s
        );
    }

    function testPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp - 1
                        )
                    )
                )
            )
        );

        vm.expectRevert(PermitExpired.selector);
        token.permit(
            owner,
            address(0xCAFE),
            1e18,
            block.timestamp - 1,
            v,
            r,
            s
        );
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testInvalidSigner() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectRevert(InvalidSigner.selector);
        token.permit(
            address(0xCAFE),
            address(0xCAFE),
            1e18,
            block.timestamp,
            v,
            r,
            s
        );
    }
}

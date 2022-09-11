// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.12;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20Votes} from "../src/interfaces/IERC20Votes.sol";
import {Comp} from "../src/mocks/Comp.sol";

/// @author These tests have been adapted from Solmate.
/// The main changes are:
///  - Use forge-std/Test.sol instead of DS-Test+
///  - Instantiate the Huff contract within the tests as opposed to the abstract contract pattern used by Solmate
///  - Using Foundry exclusively so DappTools invariant tests have been removed
///  - Discontinue use of testFail pattern in favor of vm.expectRevert
contract GasCompareTest is Test {
    IERC20Votes token;
    Comp comp;

    uint96 DEFAULT_SUPPLY = 100_000e18;
    address public bob = address(0xb0b);
    address public beef = address(0xbeef);
    address public babe = address(0xbabe);

    event GasUsed(uint256 gas, string msg);

    function deployHuff() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "huffc";
        inputs[1] = "./src/ERC20Votes.huff";
        inputs[2] = "--bytecode";
        bytes memory bytecode = vm.ffi(inputs);
        if (bytecode.length == 0) {
            revert("Could not find bytecode");
        }
        // console.logBytes(bytecode);

        assembly {
            sstore(token.slot, create(0, add(bytecode, 0x20), mload(bytecode)))
        }
        if (address(token) == address(0)) {
            console.logBytes(bytecode);
            revert("Could not deploy address");
        }
    }

    function mine() public {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function setUp() public {
        // TODO: debug why HuffDeployer is failing to deploy
        deployHuff();
        // // token = IERC20Votes(HuffDeployer.deploy("src/ERC20Votes"));
        assertEq(token.balanceOf(address(this)), token.totalSupply());
        assertEq(token.totalSupply(), 1_000_000e18);
        comp = new Comp(address(this));
        comp.transfer(babe, 10e18);
        token.transfer(babe, 10e18);
    }


    function testAverageGasDeployHuff() public {
        for (uint256 i = 0; i < 5; ) {
            deployHuff();
            unchecked {
                ++i;
            }
        }
    }

    function testAverageGasDeployComp() public {
        for (uint256 i = 0; i < 5; ) {
            new Comp(address(this));
            unchecked {
                ++i;
            }
        }
    }

    function testFunctionGas() public {
        mine();
        uint256 gasBefore = gasleft();
        comp.delegate(address(this));
        emit GasUsed(gasBefore - gasleft(), "comp.delegate()");
        gasBefore = gasleft();
        token.delegate(address(this));
        emit GasUsed(gasBefore - gasleft(), "huff.delegate()");
        mine();

        // approve()
        gasBefore = gasleft();
        comp.approve(babe, 1);
        emit GasUsed(gasBefore - gasleft(), "comp.approve()");
        gasBefore = gasleft();
        token.approve(babe, 1);
        emit GasUsed(gasBefore - gasleft(), "huff.approve()");
        mine();

        // transferFrom()
        vm.startPrank(babe);
        gasBefore = gasleft();
        comp.transferFrom(address(this), babe, 1);
        emit GasUsed(gasBefore - gasleft(), "comp.transferFrom()");
        gasBefore = gasleft();
        token.transferFrom(address(this), babe, 1);
        emit GasUsed(gasBefore - gasleft(), "huff.transferFrom()");
        mine();

        // getPriorVotes()
        gasBefore = gasleft();
        comp.getPriorVotes(address(this), 1);
        emit GasUsed(gasBefore - gasleft(), "comp.getPriorVotes()");
        gasBefore = gasleft();
        token.getPriorVotes(address(this), 1);
        emit GasUsed(gasBefore - gasleft(), "huff.getPriorVotes()");
        mine();

    }

    function testDebug() public {
        token.delegate(address(this));
        mine();
        token.transfer(bob, 1);
        token.approve(babe, 1);
        vm.startPrank(babe);
        token.transferFrom(address(this), babe, 1);
        vm.stopPrank();
    }

    function testAverageGasComp() public {
        comp.delegate(address(this));
        mine();
        for (uint256 i = 0; i < 20; ) {
            comp.transfer(bob, 1);
            comp.approve(babe, 1);
            vm.startPrank(babe);
            comp.transferFrom(address(this), babe, 1);
            vm.stopPrank();
            comp.delegates(address(this));
            comp.numCheckpoints(address(this));
            comp.checkpoints(address(this), uint32(block.number));
            comp.getCurrentVotes(address(this));
            comp.getPriorVotes(address(this), i / 2);
            comp.decimals();
            comp.balanceOf(address(this));
            mine();
            unchecked {
                ++i;
            }
        }
    }

    function testAverageGasHuff() public {
        token.delegate(address(this));
        mine();
        for (uint256 i = 0; i < 20; ) {
            token.transfer(bob, 1);
            token.approve(babe, 1);
            vm.startPrank(babe);
            token.transferFrom(address(this), babe, 1);
            vm.stopPrank();
            token.delegates(address(this));
            token.numCheckpoints(address(this));
            token.checkpoints(address(this), uint32(block.number));
            token.getCurrentVotes(address(this));
            token.getPriorVotes(address(this), i / 2);
            token.decimals();
            token.balanceOf(address(this));
            mine();
            unchecked {
                ++i;
            }
        }
    }
}

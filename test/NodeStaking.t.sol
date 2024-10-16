// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {NodelyAI} from "../src/NodelyAI.sol";
import {NodeStaking} from "../src/NodeStaking.sol";


contract TestNodeStaking is Test {
    NodelyAI public nodeToken;
    NodeStaking public nodeStaking;

        struct UserInfo {
        uint256 lastUpdateRewardToken; // Timestamp of last reward token update - used to reset user reward debt
        uint256 amount; // Amount of NODE tokens staked by the user
        uint256 rewardDebt; // Reward debt
    }

    // Admin private key
    uint256 private constant ADMIN_PK = 0x99;

    // Public address associated with admin's private key
    address private admin = vm.addr(ADMIN_PK);

    address private user1 = vm.addr(0x001);
    address private user2 = vm.addr(0x002);
    address private user3 = vm.addr(0x003);

    uint256 constant public ONE = 1e9;
    function setUp() public {
        // Labelling addresses
        vm.label(admin, "ADMIN");
        vm.label(user1, "User #1");
        vm.label(user2, "User #2");
        vm.label(user3, "User #3");

        vm.startPrank(admin);
        nodeToken = new NodelyAI();
        assertEq(nodeToken.decimals(), 9);

        nodeStaking = new NodeStaking(admin,address(nodeToken), address(nodeToken));

        // Set up rewards to distribute
        uint256 rewardToDistribute = 10000e9;
        uint256 rewardDuration = 10000;

        nodeToken.transfer(address(nodeStaking),rewardToDistribute);
        nodeStaking.updateRewards(rewardToDistribute, rewardDuration);

        nodeToken.removeUnclogLimits();

        vm.stopPrank();

        assertEq(nodeStaking.currentRewardPerBlock(), 1e9);

        // Stakers count before staking
        assertEq(nodeStaking.stakerCount(), 0);
    }

    function test_transfer_Tokens() public {
        // Balance before transfer
        assertEq(nodeToken.balanceOf(admin), 999990000e9);

        vm.prank(admin);
        nodeToken.transfer(user1, 1000e9);

        // Balances after transfer
        assertEq(nodeToken.balanceOf(admin), (999990000e9-1000e9));
        assertEq(nodeToken.balanceOf(user1), 1000e9);
    }

    function test_transferFrom_Tokens() public {
        // Approving
        vm.prank(admin);
        nodeToken.approve(user1, 1000e9);

        // Balance before transfer
        assertEq(nodeToken.balanceOf(admin), 999990000e9);

        vm.prank(user1);
        nodeToken.transferFrom(admin,user1, 1000e9);

        // Balances after transfer
        assertEq(nodeToken.balanceOf(admin), (999990000e9-1000e9));
        assertEq(nodeToken.balanceOf(user1), 1000e9);

        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        nodeToken.transferFrom(admin,user1, 1000e9);
    }

    function test_stake() public {
        // Approving
        vm.startPrank(admin);
        nodeToken.approve(address(nodeStaking), 100e9);

        // Balance before transfer
        assertEq(nodeToken.balanceOf(admin), 999990000e9);

        // Stakers count before staking
        assertEq(nodeStaking.stakerCount(), 0);

        nodeStaking.stake(admin, 100e9);

        // Stakers count after staking
        assertEq(nodeStaking.stakerCount(), 1);

        vm.stopPrank();

        // Balances after transfer
        assertEq(nodeToken.balanceOf(admin), (999990000e9-100e9));

        vm.prank(admin);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        nodeStaking.stake(admin, 100e9);
    }

    function testStakeUnstakeAndRewards() public {
        // Transfer tokens to different wallets
        uint256 user1StakeAmount = 50e9;
        uint256 user2StakeAmount = 30e9;
        uint256 user3StakeAmount = 20e9;

        // Stakers count before staking
        assertEq(nodeStaking.stakerCount(), 0);

        vm.startPrank(admin);
        nodeToken.transfer(user1, user1StakeAmount);
        nodeToken.transfer(user2, user2StakeAmount);
        nodeToken.transfer(user3, user3StakeAmount);
        vm.stopPrank();

        // Approve staking contracts from all wallets
        vm.prank(user1);
        nodeToken.approve(address(nodeStaking), user1StakeAmount);
        vm.prank(user2);
        nodeToken.approve(address(nodeStaking), user2StakeAmount);
        vm.prank(user3);
        nodeToken.approve(address(nodeStaking), user3StakeAmount);

        // Stake from all three wallets
        vm.prank(user1);
        nodeStaking.stake(user1, user1StakeAmount);
        assertEq(nodeStaking.stakerCount(), 1); // Stakers count after user 1 staking

        vm.prank(user2);
        nodeStaking.stake(user2, user2StakeAmount);
        assertEq(nodeStaking.stakerCount(), 2); // Stakers count after user 2 staking

        vm.prank(user3);
        nodeStaking.stake(user3, user3StakeAmount);
        assertEq(nodeStaking.stakerCount(), 3); // Stakers count after user 3 staking

        // Skipping 1 block
        vm.roll(2);
        assertEq(0.5e9, nodeStaking.calculatePendingRewards(user1));
        assertEq(0.3e9, nodeStaking.calculatePendingRewards(user2));
        assertEq(0.2e9, nodeStaking.calculatePendingRewards(user3));

        // Unstake user1 staked amount
        vm.prank(user1);
        nodeStaking.unstake(user1StakeAmount);
        assertEq(nodeStaking.stakerCount(), 2); // Stakers count after user 1 has unstaked all his staked tokens
        assertEq(nodeToken.balanceOf(user1), user1StakeAmount + 0.5e9);

        // Skipping 2 blocks
        vm.roll(4);
        assertEq(0, nodeStaking.calculatePendingRewards(user1));
        assertEq(1.5e9, nodeStaking.calculatePendingRewards(user2)); // 0.3 prev + 1.2 new
        assertEq(1e9, nodeStaking.calculatePendingRewards(user3)); // 0.2 prev + 0.8 new

        // Stake from user1 again
        vm.startPrank(user1);
        nodeToken.approve(address(nodeStaking), user1StakeAmount);
        nodeStaking.stake(user1, user1StakeAmount);
        assertEq(nodeToken.balanceOf(user1),0.5e9);
        assertEq(nodeStaking.stakerCount(), 3); // Stakers count after user 1 has staked again
        vm.stopPrank();

        // Skipping 2 blocks again
        vm.roll(6);
        assertEq(1e9, nodeStaking.calculatePendingRewards(user1));
        assertEq(2.1e9, nodeStaking.calculatePendingRewards(user2)); // 1.5 prev + 0.6 new
        assertEq(1.4e9, nodeStaking.calculatePendingRewards(user3)); // 1 prev + 0.4 new

        // Stake from user1 again 
        vm.prank(admin);
        nodeToken.transfer(user1,25e9);

        vm.startPrank(user1);
        nodeToken.approve(address(nodeStaking), 25e9);
        nodeStaking.stake(user1, 25e9);
        assertEq(nodeToken.balanceOf(user1),1.5e9); // New reward (1 token) claimed automatically upon staking + 0.5 prev
        assertEq(nodeStaking.stakerCount(), 3); // Stakers count remains same as user 1 has some tokens staked already
        vm.stopPrank();

        assertEq(0, nodeStaking.calculatePendingRewards(user1));
        assertEq(2.1e9, nodeStaking.calculatePendingRewards(user2)); 
        assertEq(1.4e9, nodeStaking.calculatePendingRewards(user3)); 


        // Skipping 4 more blocks
        vm.roll(10);
        assertEq(2.4e9, nodeStaking.calculatePendingRewards(user1)); // prev 0 (auto claim on last stake) + 2.4 new
        assertEq(3.06e9, nodeStaking.calculatePendingRewards(user2)); // 2.1 prev + 0.96 new
        assertEq(2.04e9, nodeStaking.calculatePendingRewards(user3)); // 1.4 prev + 0.64 new

        // Claim user 2 reward tokens and then unstake
        vm.startPrank(user2);
        nodeStaking.claim();
        assertEq(nodeToken.balanceOf(user2),3.06e9); // Reward earned
        
        nodeStaking.unstake(user2StakeAmount);
        assertEq(nodeToken.balanceOf(user2),3.06e9 + user2StakeAmount); // Reward earned + Staked amount
        assertEq(nodeStaking.stakerCount(), 2); // Stakers count decreases as user2 has unstaked all his staked tokens
        vm.stopPrank();

        // Unstake 55 user 1 staked tokens (rewards should be claimed automatically)
        vm.prank(user1); 
        nodeStaking.unstake(55e9);
        assertEq(nodeToken.balanceOf(user1),1.5e9 + 2.4e9 + 55e9); // Prev balance + New Reward amount + Unstake amount
        assertEq(nodeStaking.stakerCount(), 2); // Stakers count remains same as user 1 hasn't unstaked all his stake tokens

        // Skipping 6 more blocks
        vm.roll(16);
        assertEq(3e9, nodeStaking.calculatePendingRewards(user1)); // prev 0 (auto claim on last unstake) + 3 new
        assertEq(0, nodeStaking.calculatePendingRewards(user2)); 
        assertEq(5.04e9, nodeStaking.calculatePendingRewards(user3)); // 2.04 prev + 3 new

        // Unstake user 3 staked tokens (rewards should be claimed automatically)
        vm.prank(user3); 
        nodeStaking.unstake(user3StakeAmount);
        assertEq(nodeToken.balanceOf(user3),5.04e9 + user3StakeAmount); // Reward earned + Staked amount
        assertEq(nodeStaking.stakerCount(), 1); // Stakers count decreases as user3 has unstaked all his staked tokens

        // Unstake user 1 staked tokens (rewards should be claimed automatically)
        uint256 balanceBefore = nodeToken.balanceOf(user1);
        vm.prank(user1); 
        nodeStaking.unstake(20e9); // Remaining stake amount
        assertEq(nodeToken.balanceOf(user1),balanceBefore + 20e9 + 3e9); // Balance before + Staked amount + New rewards
        assertEq(nodeStaking.stakerCount(), 0); // Stakers count decreases as user1 has unstaked all his staked tokens
    }
}
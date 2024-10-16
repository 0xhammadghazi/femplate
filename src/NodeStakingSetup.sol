// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface INodeStaking {
    function stake(address _to, uint256 _amount) external;

    function setGovernance(address _newGovernance) external;

    function updateRewards(uint256 _reward, uint256 _rewardDurationInBlocks) external;
}

interface INodelyAI {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract NodeStakingSetup {
    INodeStaking public nodeStaking;
    INodelyAI public nodeToken;

    constructor(INodelyAI _nodeToken) {
        nodeToken = _nodeToken;
    }

    function setStakingAddress(INodeStaking _nodeStaking) external {
        nodeStaking = _nodeStaking;
    }

    function doSetup(
        address _stakeAddr,
        address _governance,
        uint256 _amountToStake,
        uint256 _rewardToDistribute,
        uint256 _rewardDuration
    ) external {
        // approve node tokens
        nodeToken.approve(address(nodeStaking), _amountToStake);

        // update rewards
        nodeStaking.updateRewards(_rewardToDistribute, _rewardDuration);

        // stake node tokens
        nodeStaking.stake(_stakeAddr, _amountToStake);

        // set governance
        nodeStaking.setGovernance(_governance);
    }
}
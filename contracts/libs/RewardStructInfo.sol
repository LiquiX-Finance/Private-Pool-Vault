// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library RewardStructInfo {

    struct TokenRewardInfo {
        uint256 totalRewardsForNextRound;
        uint256 totalRewardsForCurrentRound;
        mapping(address => uint256) userPaidMap;
    }

    struct RewardWarp {
        mapping(address => RewardStructInfo.TokenRewardInfo) tokenRewardInfoMap;
    }

    struct RewardInfo {
        address[] tokenList;
        uint256[] rewardAmountList;
        uint256[] nextRewardAmountList;
    }

}

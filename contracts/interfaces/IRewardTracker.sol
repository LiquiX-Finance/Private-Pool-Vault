// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRewardTracker {

    function payTradingFee(address token, uint256 paidFee) external;

    function claimReward() external;

}

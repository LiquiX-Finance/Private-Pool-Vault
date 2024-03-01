// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./libs/TransferHelper.sol";
import "./libs/RewardStructInfo.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardTracker is Ownable {
    using RewardStructInfo for RewardStructInfo.TokenRewardInfo;
    using RewardStructInfo for RewardStructInfo.RewardWarp;

    address public rewardContractAddress;
    address[] public allowedTokenList;
    mapping(address => bool) private allowedTokenInfo;
    uint256 public currentInfoIndex;
    mapping(uint256 => RewardStructInfo.RewardWarp) private allRewardInfoMap;
    mapping(address => uint256) public userLastClaimIndexMap;
    uint256 public lastCalculateTime;
    uint256 public bonusRate;
    uint256 public offset;
    uint256 public calculateInterval;
    uint256 public maxClaimRound;

    function initialize() external onlyOwner {
        bonusRate = 30000;
        offset = 100000;
        calculateInterval = 3 days;
        //Max Profit Accumulate: 3 years
        maxClaimRound = 365;
    }

    modifier allowTokenCheck(address token) {
        require(allowedTokenInfo[token], "IT");
        _;
    }

    function payTradingFee(address token, uint256 paidFee) external {
        if (allowedTokenInfo[token]) {
            require(paidFee > 0, "M0");
            if (currentInfoIndex > 0) {
                //Collect trading fee from user vault
                TransferHelper.safeTransferFrom(token, msg.sender, address(this), paidFee);

                //Record next round bonus info and user paid fee
                uint256 rewardAmount = (paidFee * bonusRate) / offset;
                allRewardInfoMap[currentInfoIndex].tokenRewardInfoMap[token].totalRewardsForNextRound += rewardAmount;
                allRewardInfoMap[currentInfoIndex].tokenRewardInfoMap[token].userPaidMap[msg.sender] += rewardAmount;
                if (userLastClaimIndexMap[msg.sender] == 0) {
                    userLastClaimIndexMap[msg.sender] = currentInfoIndex;
                }
                updateRewardInfo();
            }
        }
    }

    function updateRewardInfo() public {
        if (block.timestamp - lastCalculateTime >= calculateInterval) {
            createNextRoundInner();
        }
    }

    function claimReward() external {
        address user = msg.sender;
        RewardStructInfo.RewardInfo memory info = getRewardInfo(user);
        userLastClaimIndexMap[user] = currentInfoIndex;
        uint256 totalAmount = 0;
        for(uint16 i = 0; i < info.tokenList.length; i++) {
            if (info.rewardAmountList[i] > 0) {
                uint256 amount = info.rewardAmountList[i];
                TransferHelper.safeTransfer(info.tokenList[i], user, amount);
                totalAmount += amount;
            }
        }
        require(totalAmount > 0, "No Bonus");
    }

    function increaseIncentiveForCurrentRound(address token, uint256 incentive) external onlyOwner {
        require(incentive > 0, "M0");
        //Send incentive from admin
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), incentive);
        allRewardInfoMap[currentInfoIndex].tokenRewardInfoMap[token].totalRewardsForCurrentRound += incentive;
    }

    function forceCreateNextRound() public onlyOwner {
        createNextRoundInner();
    }

    function createNextRoundInner() internal {
        lastCalculateTime = block.timestamp;
        currentInfoIndex++;
        for (uint16 i = 0; i < allowedTokenList.length; i++) {
            allRewardInfoMap[currentInfoIndex].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForCurrentRound = allRewardInfoMap[currentInfoIndex - 1].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForNextRound;
        }
    }

    function insertFirstRewardInfo(address[] memory tokenList, uint256[] memory amount) external onlyOwner {
        require(currentInfoIndex == 0, "NF");
        for(uint16 i = 0; i < tokenList.length; i++) {
            allRewardInfoMap[0].tokenRewardInfoMap[tokenList[i]].totalRewardsForNextRound = amount[i];
        }
        currentInfoIndex++;
        for (uint16 i = 0; i < allowedTokenList.length; i++) {
            allRewardInfoMap[1].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForCurrentRound = allRewardInfoMap[0].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForNextRound;
        }
        lastCalculateTime = block.timestamp;
    }

    function initAllowToken(address[] memory tokenList) external onlyOwner {
        delete allowedTokenList;
        for(uint16 i = 0; i < tokenList.length; i++) {
            allowedTokenList.push(tokenList[i]);
            allowedTokenInfo[tokenList[i]] = true;
        }
    }

    function updateBasicInfo(uint256 _bonusRate, uint256 _offset, uint256 _calculateInterval, uint256 _maxClaimRound) external onlyOwner {
        bonusRate = _bonusRate;
        offset = _offset;
        calculateInterval = _calculateInterval;
        maxClaimRound = _maxClaimRound;
    }

    function getRewardInfo(address user) public view returns (RewardStructInfo.RewardInfo memory info) {
        address[] memory tokenList = new address[](allowedTokenList.length);
        uint256[] memory amountList = new uint256[](allowedTokenList.length);
        for (uint16 j = 0; j < allowedTokenList.length; j++) {
            uint256 myReward = 0;
            for (uint256 i = currentInfoIndex - 1; i >= userLastClaimIndexMap[user]; i--) {
                if ((i + maxClaimRound) <= currentInfoIndex - 1) {
                    break;
                }
                uint256 currentAllPaid = allRewardInfoMap[i].tokenRewardInfoMap[allowedTokenList[j]].totalRewardsForNextRound;
                if (currentAllPaid > 0) {
                    uint256 currentRoundReward = allRewardInfoMap[i].tokenRewardInfoMap[allowedTokenList[j]].totalRewardsForCurrentRound;
                    uint256 myPaid = allRewardInfoMap[i].tokenRewardInfoMap[allowedTokenList[j]].userPaidMap[user];
                    myReward += (myPaid * currentRoundReward * offset) / currentAllPaid / offset;
                }
                if (i == 0) {
                    break;
                }
            }
            tokenList[j] = allowedTokenList[j];
            amountList[j] = myReward;
        }
        info.tokenList = tokenList;
        info.rewardAmountList = amountList;
        return info;
    }

    function queryRewardInfo(uint256 round) public view returns(RewardStructInfo.RewardInfo memory info) {
        address[] memory tokenList = new address[](allowedTokenList.length);
        uint256[] memory amountList = new uint256[](allowedTokenList.length);
        uint256[] memory nextRewardList = new uint256[](allowedTokenList.length);
        for(uint16 i = 0; i < allowedTokenList.length; i++) {
            tokenList[i] = allowedTokenList[i];
            amountList[i] = allRewardInfoMap[round].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForCurrentRound;
            nextRewardList[i] = allRewardInfoMap[round].tokenRewardInfoMap[allowedTokenList[i]].totalRewardsForNextRound;
        }
        info.tokenList = tokenList;
        info.rewardAmountList = amountList;
        info.nextRewardAmountList = nextRewardList;
        return info;
    }

    // Receive ETH
    receive() external payable {}

    // Withdraw ERC20 tokens
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    // Withdraw ETH
    function withdrawETH(uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, amount);
    }

}

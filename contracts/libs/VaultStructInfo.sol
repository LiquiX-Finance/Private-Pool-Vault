// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./TransferHelper.sol";
import "../interfaces/ISwapRouter02.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "../interfaces/IRewardTracker.sol";

    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }

    enum GasMode {
        VOID,
        CLAIMABLE
    }

interface IERC20Rebasing {
    function configure(YieldMode) external returns (uint256);
}

interface IBlast {
    function configureClaimableGas() external;
    function configureAutomaticYield() external;
    function claimAllGas(address contractAddress, address recipient) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipient) external returns (uint256);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
}

interface IBlastPoints {
    function configurePointsOperator(address operator) external;
}

library VaultStructInfo {


    /*
        Soc Basic Info
    */
    struct BasicInfo {
        string vaultName;
        address dispatcher;
    }

    function initBasicInfo(BasicInfo storage basicInfo, string memory _vaultName, address _dispatcher) internal {
        basicInfo.vaultName = _vaultName;
        basicInfo.dispatcher = _dispatcher;
    }


    /*
        Soc Blast Info
    */

    struct BlastInfo {
        bool isInited;
        IBlast BLAST;
        IERC20Rebasing USDB_Blast;
        IERC20Rebasing WETH_Blast;
        IBlastPoints BLAST_POINT;
    }

    function initBlastInfo(BlastInfo storage blastInfo) internal {
        if (!blastInfo.isInited) {
            blastInfo.isInited = true;
            blastInfo.USDB_Blast = IERC20Rebasing(0x4200000000000000000000000000000000000022);
            blastInfo.WETH_Blast = IERC20Rebasing(0x4200000000000000000000000000000000000023);
            blastInfo.BLAST = IBlast(0x4300000000000000000000000000000000000002);
            blastInfo.BLAST_POINT = IBlastPoints(0x2fc95838c71e76ec69ff817983BFf17c710F34E0);
            blastInfo.BLAST_POINT.configurePointsOperator(msg.sender);
            blastInfo.BLAST.configureClaimableGas();
            blastInfo.BLAST.configureAutomaticYield();
            blastInfo.USDB_Blast.configure(YieldMode.AUTOMATIC);
            blastInfo.WETH_Blast.configure(YieldMode.AUTOMATIC);
        }
    }


    /*
        Vault Allowlist Token Mapping
    */
    struct AllowTokenObj {
        address tokenAddress;
        address aTokenAddress;
        bool allowed;
    }

    struct TokenAllowedInfo {
        AllowTokenObj[] allowList;
        mapping(address => AllowTokenObj) tokenExists;
    }

    function initTokenAllowedInfo(TokenAllowedInfo storage tokenAllowedInfo, address[] memory allowTokens) internal {
        delete tokenAllowedInfo.allowList;
        for (uint i = 0; i < allowTokens.length; i++) {
            AllowTokenObj memory obj = AllowTokenObj({
                tokenAddress : allowTokens[i],
                aTokenAddress : tokenAllowedInfo.tokenExists[allowTokens[i]].aTokenAddress,
                allowed : true
            });
            tokenAllowedInfo.allowList.push(obj);
            tokenAllowedInfo.tokenExists[allowTokens[i]] = obj;
        }
    }

    function setSwapAllowList(TokenAllowedInfo storage tokenAllowedInfo, AllowTokenObj[] memory _allowList) internal {
        delete tokenAllowedInfo.allowList;
        for (uint i = 0; i < _allowList.length; i++) {
            tokenAllowedInfo.allowList.push(_allowList[i]);
            tokenAllowedInfo.tokenExists[_allowList[i].tokenAddress] = _allowList[i];
        }
    }


    /*
        Uniswap Info
    */
    struct UniInfo {
        address WETH;
        ISwapRouter02 swapRouter;
        INonfungiblePositionManager nonfungiblePositionManager;
    }

    function initUniInfo(UniInfo storage uniInfo) internal {
        uniInfo.WETH = 0x4200000000000000000000000000000000000023;
        uniInfo.nonfungiblePositionManager = INonfungiblePositionManager(0x46Eb7Cff688ea0defCB75056ca209d7A2039fDa8);
        uniInfo.swapRouter = ISwapRouter02(0xE4690BD7A9cFc681A209443BCE31aB943F9a9459);
    }


    /*
        Trading Fee Info
    */
    struct TradingFeeObj {
        uint256 pendingCollectFee;
        uint16 txCount;
    }

    struct TradingInfo {
        uint8 sendTradingFeeInterval;
        uint8 tradingFee;
        uint16 swapTradingFeeRate;
        uint16 lpTradingFeeRate;
        mapping(address => TradingFeeObj) tradingFeeMap;
        uint16 aaveFeeRate;
        IRewardTracker rewardTracker;
    }

    function initTradingInfo(TradingInfo storage tradingInfo) internal {
        tradingInfo.tradingFee = 1;
        tradingInfo.swapTradingFeeRate = 5000;
        tradingInfo.lpTradingFeeRate = 10;
        tradingInfo.aaveFeeRate = 10;
        tradingInfo.sendTradingFeeInterval = 1;
        tradingInfo.rewardTracker = IRewardTracker(0x26053C592a73589406d2B55d88E3b2421aA78528);
    }

    function collectTradingFee(TradingInfo storage tradingInfo, uint256 amount, uint16 feeRate, address token) internal returns (uint256) {
        if (amount > 0) {
            uint256 fee = (amount * tradingInfo.tradingFee) / feeRate;
            TransferHelper.safeApprove(token, address(tradingInfo.rewardTracker), fee);
            tradingInfo.rewardTracker.payTradingFee(token, fee);
            return amount - fee;
        } else {
            return amount;
        }
    }

    function claimRewards(TradingInfo storage tradingInfo) internal {
        tradingInfo.rewardTracker.claimReward();
    }


    /*
        Vault Approve Info
    */
    struct ApproveInfo {
        mapping(address => bool) liquidityApproveMap;
        mapping(address => bool) swapApproveMap;
    }


    /*
        LP Removed Info
    */
    struct LpRemoveRecord {
        address token0;
        address token1;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 token0FeeAmount;
        uint256 token1FeeAmount;
    }


    /*
        LP Profit Info
    */
    struct LpClaimRecord {
        uint256 token0Claimed;
        uint256 token1Claimed;
    }

    struct ProfitInfo {
        mapping(uint256 => LpClaimRecord) claimedProfit;
        mapping(address => uint256) totalProfit;
    }

}
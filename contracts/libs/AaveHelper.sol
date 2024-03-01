// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IPool.sol";
import "./VaultStructInfo.sol";

library AaveHelper {

    struct AaveInfo {
        IPool aavePool;
        bool autoStake;
        mapping(address => bool) aaveApproveMap;
    }

    function initAaveInfo(AaveInfo storage aaveInfo) internal {
//        aaveInfo.aavePool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    }

    function depositAll(AaveInfo storage aaveInfo, VaultStructInfo.TokenAllowedInfo storage tokenAllowedInfo) internal {
//        for(uint16 i = 0; i < tokenAllowedInfo.allowList.length; i++) {
//            VaultStructInfo.AllowTokenObj memory object = tokenAllowedInfo.allowList[i];
//            if(tokenAllowedInfo.tokenExists[object.tokenAddress].aTokenAddress != address(0)) {
//                deposit(aaveInfo, object.tokenAddress, object.aTokenAddress, IERC20(object.tokenAddress).balanceOf(address(this)));
//            }
//        }
    }

    function withdrawAll(AaveInfo storage aaveInfo, VaultStructInfo.TokenAllowedInfo storage tokenAllowedInfo) internal {
//        for(uint16 i = 0; i < tokenAllowedInfo.allowList.length; i++) {
//            VaultStructInfo.AllowTokenObj memory object = tokenAllowedInfo.allowList[i];
//            if (object.aTokenAddress != address(0)) {
//                uint256 balance = IERC20(object.aTokenAddress).balanceOf(address(this));
//                if (balance > 0) {
//                    withdraw(aaveInfo, object.tokenAddress, type(uint256).max);
//                }
//            }
//        }
    }

    function withdraw(AaveInfo storage aaveInfo, address token, uint256 amount) internal returns(uint256) {
//        if (amount > 0) {
//            return aaveInfo.aavePool.withdraw(token, amount, address(this));
//        }
//        return 0;
    }

    function deposit(AaveInfo storage aaveInfo, address token, address aToken, uint256 amount) internal {
//        if (amount > 0 && aToken != address(0)) {
//            if (!aaveInfo.aaveApproveMap[token]) {
//                TransferHelper.safeApprove(token, address(aaveInfo.aavePool), type(uint256).max);
//                aaveInfo.aaveApproveMap[token] = true;
//            }
//            aaveInfo.aavePool.supply(token, amount, address(this), 0);
//        }
    }

}

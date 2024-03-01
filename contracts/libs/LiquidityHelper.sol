// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TransferHelper.sol";
import "../interfaces/INonfungiblePositionManager.sol";

library LiquidityHelper {

    struct Deposit {
        uint256 customerId;
        address token0;
        address token1;
    }

    struct PositionMap {
        mapping(uint256 => Deposit) store;
        mapping(uint256 => bool) keyExists;
        uint256[] keys;
    }

    struct CreateLpObject {
        uint256 customerId;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 token0Amount;
        uint256 token1Amount;
    }

    function mintNewPosition(PositionMap storage positionMap, CreateLpObject memory createLpObj, INonfungiblePositionManager nonfungiblePositionManager, mapping(address => bool) storage approveMap) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        if(!approveMap[createLpObj.token0]) {
            TransferHelper.safeApprove(createLpObj.token0, address(nonfungiblePositionManager), type(uint256).max);
            approveMap[createLpObj.token0] = true;
        }
        if(!approveMap[createLpObj.token1]) {
            TransferHelper.safeApprove(createLpObj.token1, address(nonfungiblePositionManager), type(uint256).max);
            approveMap[createLpObj.token1] = true;
        }
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: createLpObj.token0,
                token1: createLpObj.token1,
                fee: createLpObj.fee,
                tickLower: createLpObj.tickLower,
                tickUpper: createLpObj.tickUpper,
                amount0Desired: createLpObj.token0Amount,
                amount1Desired: createLpObj.token1Amount,
                amount0Min: createLpObj.token0Amount * 9800000 / 10000000,
                amount1Min: createLpObj.token1Amount * 9800000 / 10000000,
                recipient: address(this),
                deadline: block.timestamp + (15 minutes)
            });
        (tokenId, , amount0, amount1) = nonfungiblePositionManager.mint(params);
        positionMap.store[tokenId] = Deposit({
            customerId: createLpObj.customerId,
            token0: createLpObj.token0,
            token1: createLpObj.token1
        });
        positionMap.keys.push(tokenId);
        positionMap.keyExists[tokenId] = true;
        return (tokenId, amount0, amount1);
    }

    function increaseLiquidityCurrentRange(INonfungiblePositionManager nonfungiblePositionManager, uint256 tokenId, uint256 amountAdd0, uint256 amountAdd1) internal returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
                            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amountAdd0,
                amount1Desired: amountAdd1,
                amount0Min: amountAdd0 * 9800000 / 10000000,
                amount1Min: amountAdd0 * 9800000 / 10000000,
                deadline: block.timestamp + (15 minutes)
            });
        (, amount0, amount1) = nonfungiblePositionManager.increaseLiquidity(params);
        return (amount0, amount1);
    }

    function queryLiquidityById(uint256 tokenId, INonfungiblePositionManager nonfungiblePositionManager) internal view returns (uint128 liquidity) {
        return nonfungiblePositionManager.positions(tokenId).liquidity;
    }

    function getTokenIdByCustomerId(PositionMap storage positionMap, uint256 customerId) internal view returns (uint256) {
        for (uint i = 0; i < positionMap.keys.length; i++) {
            if (positionMap.store[positionMap.keys[i]].customerId == customerId) {
                return positionMap.keys[i];
            }
        }
        return 0;
    }

    function removeAllPositionById(uint256 tokenId, INonfungiblePositionManager nonfungiblePositionManager, uint256 amount0Min, uint256 amount1Min) internal returns (uint256 amount0, uint256 amount1) {
        uint128 liquidity = queryLiquidityById(tokenId, nonfungiblePositionManager);
        if (liquidity > 0) {
            return nonfungiblePositionManager.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp + (15 minutes)
            }));
        }
        return (0, 0);
    }

    function collectAllFees(uint256 tokenId, INonfungiblePositionManager nonfungiblePositionManager) internal returns (uint256 amount0, uint256 amount1) {
        return nonfungiblePositionManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        }));
    }

    function burn(uint256 tokenId, INonfungiblePositionManager nonfungiblePositionManager) internal {
        nonfungiblePositionManager.burn(tokenId);
    }

    function deleteDeposit(PositionMap storage positionMap, uint256 key) internal {
        if(positionMap.keyExists[key]) {
            delete positionMap.store[key];
            positionMap.keyExists[key] = false;
            for (uint i = 0; i < positionMap.keys.length; i++) {
                if (positionMap.keys[i] == key) {
                    positionMap.keys[i] = positionMap.keys[positionMap.keys.length - 1];
                    positionMap.keys.pop();
                    break;
                }
            }
        }
    }

    function getAllKeys(PositionMap storage positionMap) internal view returns (uint256[] memory)  {
        return positionMap.keys;
    }

}

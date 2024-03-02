// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

/*
 Optimization 100000
*/

import "./libs/SwapHelper.sol";
import "./libs/LiquidityHelper.sol";
import "./libs/VaultStructInfo.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import "./libs/AaveHelper.sol";

contract Vault is IERC721Receiver, Ownable, ReentrancyGuard {
    using LiquidityHelper for LiquidityHelper.PositionMap;
    using VaultStructInfo for VaultStructInfo.BasicInfo;
    using VaultStructInfo for VaultStructInfo.TradingInfo;
    using VaultStructInfo for VaultStructInfo.TokenAllowedInfo;
    using VaultStructInfo for VaultStructInfo.UniInfo;
    using VaultStructInfo for VaultStructInfo.ProfitInfo;
    using VaultStructInfo for VaultStructInfo.BlastInfo;

    LiquidityHelper.PositionMap private positionMap;
    VaultStructInfo.BasicInfo private basicInfo;
    VaultStructInfo.BlastInfo private blastInfo;
    VaultStructInfo.TradingInfo private tradingInfo;
    VaultStructInfo.TokenAllowedInfo private tokenAllowedInfo;
    VaultStructInfo.UniInfo private uniInfo;
    VaultStructInfo.ApproveInfo private approveInfo;
    VaultStructInfo.ProfitInfo private profitInfo;
    mapping(uint256 => VaultStructInfo.LpRemoveRecord) private tokenIdLpInfoMap;

    function initialize(string memory _vaultName, address _dispatcher, address[] memory allowTokens) external onlyOwner {
        basicInfo.initBasicInfo(_vaultName, _dispatcher);
        tradingInfo.initTradingInfo();
        uniInfo.initUniInfo();
        tokenAllowedInfo.initTokenAllowedInfo(allowTokens);
    }

    function getVaultName() public view returns (string memory) {
        return basicInfo.vaultName;
    }

    function updateVaultName(string memory _newVaultName) external onlyOwner {
        basicInfo.vaultName = _newVaultName;
    }

    function onERC721Received(address /*operator*/, address, uint256 /*tokenId*/, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier dispatcherCheck() {
        require(basicInfo.dispatcher == msg.sender || owner() == msg.sender, "NA");
        _;
    }

    modifier onlyDispatcherCheck() {
        require(basicInfo.dispatcher == msg.sender, "NA");
        _;
    }

    modifier allowListCheck(address tokenAddress) {
        require(tokenAllowedInfo.tokenExists[tokenAddress].allowed, "NA");
        _;
    }

    /*
    * Swap
    */
    /*
    function swapInputETHForToken(address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMin) external dispatcherCheck allowListCheck(tokenOut) returns (uint256 amountOut) {
        amountOut = SwapHelper.swapInputETHForToken(tokenOut, fee, amountIn, amountOutMin, uniInfo.swapRouter, uniInfo.WETH);
        return tradingInfo.collectTradingFee(amountOut, tradingInfo.swapTradingFeeRate, tokenOut);
    }
    */

    /*
    function swapInputTokenToETH(address tokenIn, uint24 fee, uint256 amountIn, uint256 amountOutMin) external dispatcherCheck returns (uint256) {
        return SwapHelper.swapInputTokenToETH(tokenIn, fee, amountIn, amountOutMin, uniInfo.swapRouter, uniInfo.WETH, approveInfo.swapApproveMap);
    }
    */

    function swapInputForErc20Token(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMin) external dispatcherCheck allowListCheck(tokenOut) returns (uint256 amountOut) {
        amountOut = SwapHelper.swapInputForErc20Token(tokenIn, tokenOut, fee, amountIn, amountOutMin, uniInfo.swapRouter, approveInfo.swapApproveMap);
        return tradingInfo.collectTradingFee(amountOut, tradingInfo.swapTradingFeeRate, tokenOut);
    }

    /*
    * Liquidity
    */
    function mintPosition(LiquidityHelper.CreateLpObject memory createLpObject) public dispatcherCheck allowListCheck(createLpObject.token0) allowListCheck(createLpObject.token1) {
        positionMap.mintNewPosition(createLpObject, uniInfo.nonfungiblePositionManager, approveInfo.liquidityApproveMap);
    }

    function mintPositions(LiquidityHelper.CreateLpObject[] memory createLpObject) external dispatcherCheck {
        for (uint16 i = 0; i < createLpObject.length; i++) {
            mintPosition(createLpObject[i]);
        }
    }

    function increaseLiquidity(uint256 positionId, uint256 token0Amount, uint256 token1Amount) external dispatcherCheck {
        LiquidityHelper.increaseLiquidityCurrentRange(uniInfo.nonfungiblePositionManager, positionId, token0Amount, token1Amount);
    }

    function removeAllPositionById(uint256 positionId) public dispatcherCheck {
        (uint256 amount0, uint256 amount1) = LiquidityHelper.removeAllPositionById(positionId, uniInfo.nonfungiblePositionManager, 0, 0);
        if (amount0 + amount1 > 0) {
            (uint256 amount0Fee, uint256 amount1Fee) = collectAllFeesInner(positionId, amount0, amount1);
            tokenIdLpInfoMap[positionId] = VaultStructInfo.LpRemoveRecord({
                token0: positionMap.store[positionId].token0,
                token1: positionMap.store[positionId].token1,
                token0Amount: amount0,
                token1Amount: amount1,
                token0FeeAmount: amount0Fee,
                token1FeeAmount: amount1Fee
            });
            positionMap.deleteDeposit(positionId);
        }
    }

    function removeAllPositionByIds(uint256[] memory positionIds) external dispatcherCheck {
        for (uint16 i = 0; i < positionIds.length; i++) {
            removeAllPositionById(positionIds[i]);
        }
    }

    function removeLpInfoByTokenIds(uint256[] memory tokenIds) external dispatcherCheck {
        for (uint16 i = 0; i < tokenIds.length; i++) {
            delete tokenIdLpInfoMap[tokenIds[i]];
        }
    }

    function collectAllFees(uint256 positionId) external dispatcherCheck {
        collectAllFeesInner(positionId, 0, 0);
    }

    function collectMultiLpFees(uint256[] memory positionIds) external dispatcherCheck {
        for (uint16 i = 0; i < positionIds.length; i++) {
            collectAllFeesInner(positionIds[i], 0, 0);
        }
    }

    function burnNFT(uint128 tokenId) external dispatcherCheck {
        LiquidityHelper.burn(tokenId, uniInfo.nonfungiblePositionManager);
        positionMap.deleteDeposit(tokenId);
    }

    function collectAllFeesInner(uint256 positionId, uint256 amount0Principal, uint256 amount1Principal) internal returns (uint256 amount0TotalFee, uint256 amount1TotalFee) {
        (uint256 amount0FeeWithPrincipal, uint256 amount1FeeWithPrincipal) = LiquidityHelper.collectAllFees(positionId, uniInfo.nonfungiblePositionManager);
        uint256 amount0Fee = amount0FeeWithPrincipal - amount0Principal;
        uint256 amount1Fee = amount1FeeWithPrincipal - amount1Principal;
        tradingInfo.collectTradingFee(amount0Fee, tradingInfo.lpTradingFeeRate, positionMap.store[positionId].token0);
        tradingInfo.collectTradingFee(amount1Fee, tradingInfo.lpTradingFeeRate, positionMap.store[positionId].token1);
        profitInfo.claimedProfit[positionId].token0Claimed = profitInfo.claimedProfit[positionId].token0Claimed + amount0Fee;
        profitInfo.claimedProfit[positionId].token1Claimed = profitInfo.claimedProfit[positionId].token1Claimed + amount1Fee;
        profitInfo.totalProfit[positionMap.store[positionId].token0] = profitInfo.totalProfit[positionMap.store[positionId].token0] + amount0Fee;
        profitInfo.totalProfit[positionMap.store[positionId].token1] = profitInfo.totalProfit[positionMap.store[positionId].token1] + amount1Fee;
        return (profitInfo.claimedProfit[positionId].token0Claimed, profitInfo.claimedProfit[positionId].token1Claimed);
    }

    /*
    * Loan
    */
    function depositAllToAave() external dispatcherCheck {

    }

    function withdrawAllFromAave() external dispatcherCheck {

    }

    /*
    * Periphery functions
    */
    function setDispatcher(address _dispatcher) external onlyOwner {
        basicInfo.dispatcher = _dispatcher;
    }

    function setSwapAllowList(VaultStructInfo.AllowTokenObj[] memory _allowList) external onlyOwner {
        tokenAllowedInfo.setSwapAllowList(_allowList);
    }

    function updateTradingFee(uint8 _tradingFee) external onlyDispatcherCheck {
        require(_tradingFee <= 3, "TI");
        tradingInfo.tradingFee = _tradingFee;
    }

    function setAutoStake(bool _autoStake, VaultStructInfo.AllowTokenObj[] memory allowedTokens) external onlyOwner {
        blastInfo.initBlastInfo();
    }

    function claimRewards() external onlyOwner {
        tradingInfo.claimRewards();
    }

    function claimGas(uint8 claimType) external onlyOwner {
        if (claimType == 0) {
            blastInfo.BLAST.claimAllGas(address(this), msg.sender);
        } else if (claimType == 1) {
            blastInfo.BLAST.claimMaxGas(address(this), msg.sender);
        }
    }

    /*
    * View functions
    */
    function getPositionIds() external view returns (uint256[] memory) {
        return positionMap.getAllKeys();
    }

    function getTokenIdByCustomerId(uint256 customerId) public view returns (uint256) {
        return positionMap.getTokenIdByCustomerId(customerId);
    }

    function queryRemovedLpInfo(uint256 tokenId) public view returns (VaultStructInfo.LpRemoveRecord memory) {
        return tokenIdLpInfoMap[tokenId];
    }

    function queryLpClaimedProfit(uint256 tokenId) public view returns (uint256 amount0Claimed, uint256 amount1Claimed) {
        return (profitInfo.claimedProfit[tokenId].token0Claimed, profitInfo.claimedProfit[tokenId].token1Claimed);
    }

    function queryTotalClaimedProfit(address[] memory tokenAddress) public view returns (uint256[] memory) {
        uint256[] memory claimedArray = new uint256[](tokenAddress.length);
        for (uint16 i = 0; i < tokenAddress.length; i++) {
            claimedArray[i] = profitInfo.totalProfit[tokenAddress[i]];
        }
        return claimedArray;
    }

    function getAllowTokenList() public view returns (VaultStructInfo.AllowTokenObj[] memory) {
        return tokenAllowedInfo.allowList;
    }

    function balanceOf(bool isNativeToken, address token) public view returns (uint256) {
        if (isNativeToken) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    function isAutoStake() public view returns (bool) {
        return blastInfo.isInited;
    }

    function readGasParams() public view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode) {
        return blastInfo.BLAST.readGasParams(address(this));
    }

    /*
    * Asset management
    */
    receive() external payable {}

    function withdrawErc721NFT(uint256 tokenId) external onlyOwner {
        uniInfo.nonfungiblePositionManager.safeTransferFrom(address(this), msg.sender, tokenId);
        positionMap.deleteDeposit(tokenId);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        if(token == uniInfo.WETH) {
            IWETH(uniInfo.WETH).withdraw(amount);
            TransferHelper.safeTransferETH(msg.sender, amount);
        } else {
            TransferHelper.safeTransfer(token, msg.sender, amount);
        }
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, amount);
    }

    function deposit(address depositToken, uint256 amount) external onlyOwner {
        TransferHelper.safeTransferFrom(depositToken, msg.sender, address(this), amount);
    }

    function depositEthToWeth() external payable onlyOwner {
        IWETH(uniInfo.WETH).deposit{value: msg.value}();
    }

    function depositGasToDispatcher(uint256 amount) external onlyOwner {
        IWETH(uniInfo.WETH).withdraw(amount);
        TransferHelper.safeTransferETH(basicInfo.dispatcher, amount);
    }

}
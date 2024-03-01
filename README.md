![Logo](https://liquix.s3.ap-northeast-1.amazonaws.com/Title-Logo.png)

# LiquiX
#### [Official website https://liquix.finance](https://liquix.finance/)
#### [tyler@liquix.finance](mailto:tyler@liquix.finance)

<BR>

### Global Liquidity Made Easy

LiquiX stands as the pioneering on-chain liquidity management infrastructure, offering a simple, secure, and effective LP solution accessible to all. 
With Liquix every body can effortlessly craft their tailored LP strategy and reap attractive returns in a secure, decentralized environment. 
After months of successful private beta testing, during which we assisted numerous seed users in achieving outstanding outcomes, we are now excited to extend an invitation to you to join the LiquiX community.

<BR>

#### Vault
***
The user's funds are stored in a dedicated on-chain vault, which will not be mixed with others. For their own vault, the user has the highest authority, and even the project party cannot misappropriate the funds.

```onlyOwner```
```solidity
    function withdrawErc721NFT(uint256 tokenId) external onlyOwner {
        uniInfo.nonfungiblePositionManager.safeTransferFrom(address(this), msg.sender, tokenId);
        positionMap.deleteDeposit(tokenId);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, amount);
    }
```
<BR>

#### Token Allowlist
***
All tokens that can be swapped and have liquidity added require permission from the user's allowlist to execute, effectively preventing hacker attacks and the bulk purchasing of shitcoins.

```solidity
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

    modifier allowListCheck(address tokenAddress) {
        require(tokenAllowedInfo.tokenExists[tokenAddress].allowed, "NA");
        _;
    }

```
<BR>

#### Idle assets automatically generate interest.
***
On different chains, we use various protocols to automatically help users generate interest from their restricted assets, all of which is seamless to the user.
* AAVE
* Blast Native Yield

<BR>

####  Audit Report
***
> https://github.com/LiquiX-Finance/Private-Pool-Vault/blob/main/SlowMist%20Audit%20Report%20-%20LiquiX.pdf
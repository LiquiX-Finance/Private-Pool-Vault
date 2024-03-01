// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./libs/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ProxyContract.sol";

contract LiquiXFactory is Ownable {

    event VaultCreated(string name, address proxyAddress);

    address[] public vaultVersion;
    address[] public deployedVault;
    mapping(address => address[]) public userVaultMapping;

    function deployVaultProxyForUser(string memory vaultName, address dispatcher, address[] memory allowTokens) external {
        ProxyContract newContract = new ProxyContract(msg.sender, vaultVersion[vaultVersion.length - 1], vaultName, dispatcher, allowTokens);
        deployedVault.push(address(newContract));
        userVaultMapping[msg.sender].push(address(newContract));
        emit VaultCreated(vaultName, address(newContract));
    }

    function setNewVaultVersion(address _vaultContractAddress) external onlyOwner {
        vaultVersion.push(_vaultContractAddress);
    }

    function getLatestVault() public view returns (address) {
        return vaultVersion[vaultVersion.length - 1];
    }

    function getUserAllVaults(address userAddress) public view returns(address[] memory) {
        return userVaultMapping[userAddress];
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

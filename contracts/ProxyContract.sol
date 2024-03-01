// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProxyContract is Ownable {

    address public vaultContractAddress;

    constructor(address _customOwner, address _vaultContractAddress, string memory vaultName, address dispatcher, address[] memory allowTokens) {
        initContractInner(_vaultContractAddress, vaultName, dispatcher, allowTokens);
        transferOwnership(_customOwner);
    }

    function upgradeLogicContract(address _vaultContractAddress, string memory vaultName, address dispatcher, address[] memory allowTokens) external onlyOwner {
        initContractInner(_vaultContractAddress, vaultName, dispatcher, allowTokens);
    }

    function initContractInner(address _vaultContractAddress, string memory vaultName, address dispatcher, address[] memory allowTokens) internal {
        vaultContractAddress = _vaultContractAddress;
        bytes memory data = abi.encodeWithSignature("initialize(string,address,address[])", vaultName, dispatcher, allowTokens);
        (bool success,) = vaultContractAddress.delegatecall(data);
        require(success, "Initialization failed");
    }

    receive() external payable {}

    fallback() external payable {
        address implementation = vaultContractAddress;
        require(implementation != address(0));

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), implementation, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

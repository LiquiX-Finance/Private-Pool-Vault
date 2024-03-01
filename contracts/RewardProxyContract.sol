// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardProxyContract is Ownable {

    address public rewardContractAddress;

    constructor(address rewardContract) {
        initContractInner(rewardContract);
    }

    function upgradeLogicContract(address rewardContract) external onlyOwner {
        initContractInner(rewardContract);
    }

    function initContractInner(address rewardContract) internal {
        rewardContractAddress = rewardContract;
        bytes memory data = abi.encodeWithSignature("initialize()");
        (bool success,) = rewardContractAddress.delegatecall(data);
        require(success, "Initialization failed");
    }

    function getCurrentRewardTracker() public view returns(address) {
        return rewardContractAddress;
    }

    receive() external payable {}

    fallback() external payable {
        address implementation = rewardContractAddress;
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

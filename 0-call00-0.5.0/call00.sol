pragma solidity 0.5.0;
contract call00 {
    function execute(bool condition, uint gasLimit, uint value, bytes memory data, address destination) public {
        require(condition);
        bool success = false;
        assembly { success := call(gasLimit, destination, value, add(data, 0x20), mload(data), 0, 0) }
        require(success);
    }
}

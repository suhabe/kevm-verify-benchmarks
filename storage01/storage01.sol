pragma solidity 0.4.24;

contract storage01 {
    uint public nonce;

    function inc() external returns (uint) {
        nonce = 1;
        return 5;
    }
}
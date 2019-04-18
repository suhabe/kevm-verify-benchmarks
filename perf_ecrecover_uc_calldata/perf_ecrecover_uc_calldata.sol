pragma solidity 0.5.0;

contract perf_ecrecover_uc_calldata {

    function get(bytes32 hash, uint8 sigV, bytes32 sigR, bytes32 sigS) public {
        require(ecrecover(hash, sigV, sigR, sigS) > address(0));
    }
}


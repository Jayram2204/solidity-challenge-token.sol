pragma solidity 0.7.0;

interface IMintableToken {
    function mint() external payable;
    function burn(address payable dest) external;
}

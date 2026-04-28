pragma solidity 0.7.0;

interface IDividends {
    function getNumTokenHolders() external view returns (uint256);
    function getTokenHolder(uint256 index) external view returns (address);
    function recordDividend() external payable;
    function getWithdrawableDividend(address payee) external view returns (uint256);
    function withdrawDividend(address payable dest) external;
}

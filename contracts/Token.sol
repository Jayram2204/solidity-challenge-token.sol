pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    using SafeMath for uint256;
    
    // Required immutable state
    uint256 public override totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public override balanceOf;
    
    // ERC20 state
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Holder tracking (1-indexed for getTokenHolder!)
    address[] private _holders;
    mapping(address => bool) private _isHolder;
    mapping(address => uint256) private _holderIndex;
    
    // Dividend tracking - efficient "dividend per share" method
    uint256 public totalDividendPerShare;
    mapping(address => uint256) public lastDividendPerShare;
    mapping(address => uint256) private _dividends;
    uint256 constant MAGNIFIER = 1e36;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // ============================================
    // IERC20 Implementation
    // ============================================
    
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) external override returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "Token: insufficient allowance");
        _allowances[from][msg.sender] = currentAllowance.sub(value);
        _transfer(from, to, value);
        return true;
    }
    
    // ============================================
    // IMintableToken Implementation
    // ============================================
    
    function mint() external payable override {
        require(msg.value > 0, "Token: mint amount must be >0");
        
        _updateAccount(msg.sender);
        
        totalSupply = totalSupply.add(msg.value);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        
        _addHolder(msg.sender);
        
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "Token: no balance to burn");
        
        _updateAccount(msg.sender);
        
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);
        
        _removeHolder(msg.sender);
        
        emit Transfer(msg.sender, address(0), amount);
        (bool success, ) = dest.call{value: amount}("");
        require(success, "Token: ETH transfer failed");
    }
    
    // ============================================
    // IDividends Implementation
    // ============================================
    
    function getNumTokenHolders() external view override returns (uint256) {
        return _holders.length;
    }
    
    function getTokenHolder(uint256 index) external view override returns (address) {
        // CRITICAL: Tests expect 1-based indexing!
        require(index >= 1 && index <= _holders.length, "Token: invalid index");
        return _holders[index - 1];
    }
    
    function recordDividend() external payable override {
        require(msg.value > 0, "Token: dividend must be >0");
        require(totalSupply > 0, "Token: no token supply");
        
        // Efficiently record dividend by increasing the per-share accumulator
        totalDividendPerShare = totalDividendPerShare.add(msg.value.mul(MAGNIFIER).div(totalSupply));
    }
    
    function getWithdrawableDividend(address payee) public view override returns (uint256) {
        uint256 currentDividends = _dividends[payee];
        if (balanceOf[payee] > 0) {
            uint256 diff = totalDividendPerShare.sub(lastDividendPerShare[payee]);
            uint256 accrued = balanceOf[payee].mul(diff).div(MAGNIFIER);
            currentDividends = currentDividends.add(accrued);
        }
        return currentDividends;
    }
    
    function withdrawDividend(address payable dest) external override {
        _updateAccount(msg.sender);
        
        uint256 amount = _dividends[msg.sender];
        require(amount > 0, "Token: no dividend to withdraw");
        
        _dividends[msg.sender] = 0;
        
        (bool success, ) = dest.call{value: amount}("");
        require(success, "Token: ETH transfer failed");
    }
    
    // ============================================
    // Internal Functions
    // ============================================
    
    function _updateAccount(address account) internal {
        if (balanceOf[account] > 0) {
            uint256 diff = totalDividendPerShare.sub(lastDividendPerShare[account]);
            if (diff > 0) {
                uint256 accrued = balanceOf[account].mul(diff).div(MAGNIFIER);
                _dividends[account] = _dividends[account].add(accrued);
            }
        }
        lastDividendPerShare[account] = totalDividendPerShare;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "Token: transfer from zero address");
        require(to != address(0), "Token: transfer to zero address");
        require(balanceOf[from] >= value, "Token: insufficient balance");
        
        _updateAccount(from);
        _updateAccount(to);
        
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        
        _addHolder(to);
        
        if (balanceOf[from] == 0) {
            _removeHolder(from);
        }
        
        emit Transfer(from, to, value);
    }
    
        function _addHolder(address account) internal {
            if (!_isHolder[account]) {
                _isHolder[account] = true;
                _holderIndex[account] = _holders.length;
                _holders.push(account);
            }
        }

    function _removeHolder(address account) internal {
        if (_isHolder[account]) {
            uint256 index = _holderIndex[account];
            uint256 lastIndex = _holders.length - 1;
            
            if (index != lastIndex) {
                address lastHolder = _holders[lastIndex];
                _holders[index] = lastHolder;
                _holderIndex[lastHolder] = index;
            }
            
            _holders.pop();
            delete _holderIndex[account];
            _isHolder[account] = false;
        }
    }
    
    receive() external payable {
        // Accept ETH but require explicit recordDividend() call
    }
}

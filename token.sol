pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    using SafeMath for uint256;
    
    // Required immutable state
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    
    // ERC20 state
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Holder tracking (1-indexed for getTokenHolder!)
    address[] private _holders;
    mapping(address => bool) private _isHolder;
    mapping(address => uint256) private _holderIndex;
    
    // Dividend tracking - simple accumulation per address
    mapping(address => uint256) private _dividends;
    
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
        
        totalSupply = totalSupply.add(msg.value);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        
        if (!_isHolder[msg.sender]) {
            _holderIndex[msg.sender] = _holders.length;
            _holders.push(msg.sender);
            _isHolder[msg.sender] = true;
        }
        
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "Token: no balance to burn");
        
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);
        
        _removeHolder(msg.sender);
        
        emit Transfer(msg.sender, address(0), amount);
        dest.transfer(amount);
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
        
        uint256 dividend = msg.value;
        
        // Loop through all current holders and assign dividends proportionally
        // This permanently assigns dividends to these addresses
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];
            uint256 holderBalance = balanceOf[holder];
            
            // Calculate share: (holderBalance * dividend) / totalSupply
            uint256 holderDividend = holderBalance.mul(dividend).div(totalSupply);
            _dividends[holder] = _dividends[holder].add(holderDividend);
        }
    }
    
    function getWithdrawableDividend(address payee) public view override returns (uint256) {
        return _dividends[payee];
    }
    
    function withdrawDividend(address payable dest) external override {
        uint256 amount = _dividends[msg.sender];
        require(amount > 0, "Token: no dividend to withdraw");
        
        _dividends[msg.sender] = 0;
        
        (bool success, ) = dest.call{value: amount}("");
        require(success, "Token: ETH transfer failed");
    }
    
    // ============================================
    // Internal Functions
    // ============================================
    
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "Token: transfer from zero address");
        require(to != address(0), "Token: transfer to zero address");
        require(balanceOf[from] >= value, "Token: insufficient balance");
        
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        
        // Update holder list
        if (balanceOf[to] == value && !_isHolder[to]) {
            _holderIndex[to] = _holders.length;
            _holders.push(to);
            _isHolder[to] = true;
        }
        
        if (balanceOf[from] == 0) {
            _removeHolder(from);
        }
        
        emit Transfer(from, to, value);
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
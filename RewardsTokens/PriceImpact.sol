/*

FEATURES
* TXN limit on launch
* Sells limited to 3% of the Liquidity Pool
* Sell cooldown increases on consecutive sells

*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {return _owner;}
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}
contract XXXXToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    string private constant _name = "XXXXX";
    string private constant _symbol = "XXX";
    uint8 private constant _decimals = 9;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 private _taxFee = 7;
    uint256 private _teamFee = 6;
    uint256 private numTokensSellToAddToLiquidity = 1000000000; 
    mapping(address => uint256) private sellcooldown;
    mapping(address => uint256) private firstsell;
    mapping(address => uint256) private sellnumber;
    address payable private _teamAddress;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen = false;
    bool private liquidityAdded = false;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool private cooldownEnabled = false;
    bool public  feesEnabled = false;
    bool private dxSaleActive = true;
    uint256 private _maxTxAmount = _tTotal;
    address dxSaleRouter;
    address dxPreSaleAddress;
    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    constructor(address payable addr1) {
        _teamAddress = addr1;
        _rOwned[_msgSender()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_teamAddress] = true;
        // uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH());
        emit Transfer(address(0), _msgSender(), _tTotal);
    }
    function name() public pure returns (string memory) {return _name;}
    function symbol() public pure returns (string memory) {return _symbol;}
    function decimals() public pure returns (uint8) {return _decimals;}
    function totalSupply() public pure override returns (uint256) { return _tTotal;}
    function balanceOf(address account) public view override returns (uint256) {return tokenFromReflection(_rOwned[account]);}
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view override returns (uint256) {return _allowances[owner][spender];}
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender,_msgSender(),_allowances[sender][_msgSender()].sub(amount,"ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function setCooldownEnabled(bool onoff) external onlyOwner() {cooldownEnabled = onoff;}
    function tokenFromReflection(uint256 rAmount) private view returns (uint256) {
        require(rAmount <= _rTotal,"Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }
    function removeAllFee() private {
        if (_taxFee == 0 && _teamFee == 0) return;
        _taxFee = 0;
        _teamFee = 0;
    }
    function restoreAllFee() private {
        _taxFee = 7;
        _teamFee = 5;
    }
    function setFee(uint256 multiplier) private {
        _taxFee = _taxFee * multiplier;
        if (multiplier > 1) {
            _teamFee = 10;
        }

    }
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        //No fee for DxRouters
        if  (dxSaleActive) {_tokenTransfer(from, to, amount, false); }
        else{
            // Add liqudity and send TeamWallet Eth if Contract accumulated enough tokens
            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
            if (from!=dxSaleRouter && from!=dxPreSaleAddress && from != uniswapV2Pair && from != address(this) && to != address(this) && overMinTokenBalance && feesEnabled && !inSwap && !_isExcludedFromFee[to]) {
                do_all_fees();}

            // Set buy fee
            if (from!=dxSaleRouter && from!=dxPreSaleAddress &&  from != owner() && to != owner() && from != address(this)) {
                if (cooldownEnabled && from != address(this) && to != address(this) && from != address(uniswapV2Router) && to != address(uniswapV2Router)) {
                    require(_msgSender() == address(uniswapV2Router) || _msgSender() == uniswapV2Pair,"ERR: Uniswap only");}
                if (from == uniswapV2Pair && to != address(uniswapV2Router) && !_isExcludedFromFee[to] ) {
                    require(tradingOpen);
                    require(amount <= _maxTxAmount);
                    _teamFee = 6;
                    _taxFee = 2;
                }


                // Set Fee Multiplicator and Sell Cooldown
                if (from!=dxSaleRouter && from!=dxPreSaleAddress && !inSwap && from != uniswapV2Pair &&  swapEnabled && feesEnabled) {
                    require(amount <= balanceOf(uniswapV2Pair).mul(3).div(100) && amount <= _maxTxAmount); // Price impact of the uniswapV2Pair is 3%
                    require(sellcooldown[from] < block.timestamp);
                    // After 1 Days cooldown the multiplicative factor goes back to 0
                    if(firstsell[from] + (1 days) < block.timestamp){ sellnumber[from] = 0;}
                    if (sellnumber[from] == 0) {
                        // Initial Fee for first sell
                        sellnumber[from]++;
                        firstsell[from] = block.timestamp;                  // 0H   ------> 0 CLOCK
                        sellcooldown[from] = block.timestamp + (1 hours); // 1H   ------> 1 CLOCK
                        _teamFee = 6;
                        _taxFee = 7;
                    }
                    else if (sellnumber[from] == 1) {
                        // Fee for 2nd sell
                        sellnumber[from]++;
                        sellcooldown[from] = block.timestamp + (2 hours); // 2H  -----> 3 CLOCK
                        _teamFee = 12;
                        _taxFee =14;
                    }
                    else if (sellnumber[from] == 2) {
                        // Fee for 3rd sell
                        sellnumber[from]++;
                        setFee(sellnumber[from]);
                        sellcooldown[from] = block.timestamp + (3 hours); // 3H  ------> 6 CLOCK
                        _teamFee = 12;
                        _taxFee =21;
                    }
                    else if (sellnumber[from] == 3) {
                        sellnumber[from]++;
                        // Fee for 4th sell
                        sellcooldown[from] = block.timestamp + (4 hours); // 6H  -------> 12 CLOCK
                        _teamFee = 12;
                        _taxFee =28;
                    } else {
                        // Fee for 5th sell
                        _teamFee = 12;
                        _taxFee =35;
                        sellcooldown[from] = block.timestamp + (10 hours); // 12   ------>  24 Clock

                    }
                }
            }

            bool takeFee = true;
            if (_isExcludedFromFee[from] || _isExcludedFromFee[to] && feesEnabled ) { takeFee = false;}
            _tokenTransfer(from, to, amount, takeFee);
            // Reset Fee multipliers after all transfers done
            restoreAllFee;
        }}
    function do_all_fees() private lockTheSwap{
        // All Liqudity Pool Related Fees
        uint256 contractTokenBalance = balanceOf(address(this));
        if(contractTokenBalance >= _maxTxAmount){contractTokenBalance = _maxTxAmount;}
        swapAndLiquify(contractTokenBalance);
    }
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {

        //1. Take 50% of the XXXXX-Tokens accumulated in the XXXXX-Contract via Fees and Trade these 50% into Ethereum with uniswap
        //2. Now the Contract has some ETHEREUM, lets say N ETHEREUM. Split into 2 equal parts, i.e N/2.
        // 3. 50% of ETH + 50% of XXXXX tokens sent to Uniswap for Liqudity. LP Tokens sent to Team Wallet
        // 4. Send Remaining 50% of Eth to Team Wallet
        // Summary : We swap 50% of XXXXX for Eth, then use the reamining 50% XXXXX + 50% of new ETH for Liqudity. Finally, Remaining 50% Eth goes to TeamWallet. 100% XXXXX and 100% Eth used up

        // split the contract Eth balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the swap creates, and not make the liquidity event include any ETH that has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap half of all XXXXX tokens for ETH Into the XXXXX Contract
        swapTokensForEth(half);

        // how much ETH did the contract just swap into?
        // We just work with 90% of our ETH, to avoid Swapping ALL eth and running out of Gas for further Swaps.
        uint256 newBalance  = address(this).balance.sub(initialBalance).mul(90).div(100);

        // Take the Pools Share of the ETH and use the rest for Team
        // 0.17% of the LiquiTeamFee is for the Pool and the remainder for the Team.
        // Example : 100 XXXXX Sold -> 6% LiquiPoolFee=6 Tokens.
        // 6 * 0.17 = 1.02% --> Pool Share
        // 6 - 1.02 = 4.98% --> Team Share
        uint256 poolFractionOfLiquiTeamFee = 17;
        uint256 poolBalance =  newBalance.mul(poolFractionOfLiquiTeamFee).div(100);
        uint256 teamBalance =  newBalance.sub(poolBalance);

        // add liquidity to uniswap with the reamining 50% XXXXX and the poolShare of the Eth
        addLiquidity(otherHalf, poolBalance);

        // Send Eth Teamshare to Teamwallet
        sendEthToTeam(teamBalance);

        emit SwapAndLiquify(half, poolBalance, otherHalf);
    }
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }
    function sendEthToTeam(uint256 amount) private {_teamAddress.transfer(amount);}
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this),tokenAmount,0,0,owner(),block.timestamp);
    }
    function toggleFeesOFF() external onlyOwner() {
        swapEnabled = false;
        cooldownEnabled = false;
        feesEnabled = false;
        dxSaleActive = true;
    }

    function toggleFeesONAndLaunch() external onlyOwner() {
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // pancake bscnet
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH());
        swapEnabled = true;
        cooldownEnabled = false;
        liquidityAdded = true;
        feesEnabled = true;
        tradingOpen = true;
        dxSaleActive = false;
    }

    function manualswap() external {
        require(_msgSender() == _teamAddress);
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function manualsend() external {
        require(_msgSender() == _teamAddress);
        uint256 contractETHBalance = address(this).balance;
        sendEthToTeam(contractETHBalance);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getTValues(tAmount, _taxFee, _teamFee);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tTeam, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
    }

    function _getTValues(uint256 tAmount, uint256 taxFee, uint256 teamFee) private pure returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tTeam = tAmount.mul(teamFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam);
        return (tTransferAmount, tFee, tTeam);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tTeam, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        // Set what the maxmimum tx size may be in %, respective to total liqudity
        require(maxTxPercent > 0, "Amount must be greater than 0");
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function setDxSaleRouter(address dxSaleRouterAddress, address dxPreSaleAddressToSet) external onlyOwner() {
        dxSaleRouter     = dxSaleRouterAddress ;
        dxPreSaleAddress = dxPreSaleAddressToSet ;
        _isExcludedFromFee[dxSaleRouter] = true;
        _isExcludedFromFee[dxPreSaleAddress] = true;

    }
    function setNumTokensSellToAddToLiquidity(uint256 newValue) external onlyOwner() {
        // Set what the maxmimum tx size may be in %, respective to total liqudity
        require(newValue > 0, "Amount must be greater than 0");
        numTokensSellToAddToLiquidity = newValue;
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    receive() external payable {}
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "contracts/IERC20.sol";
import "contracts/governanceInterface.sol";
import "contracts/OSMInterface.sol";

contract USTN is IERC20 {

    event convert(uint _time, address _user, uint _unitValueTotal, uint _USTNAmount, string _type);
    
    string public constant name = "ustn token";
    uint8 public constant decimals = 18;
    string public constant symbol = "USTN";
    string constant unit="UNIT";
    string constant ustn="USTN";
    uint256 public _totalSupply;
    mapping(address => uint256) _balance;
    mapping(address => mapping(address => uint256)) _approve;
    
    governanceInterface verifyAddress;
    OSMInterface queryData;

    
    constructor(address governanceAddress) {
        verifyAddress = governanceInterface(governanceAddress);
    }

    modifier onlyContract(string memory _name) {
        require(verifyAddress.checkTargetSenderContractGroup(_name, msg.sender), "Only Contract");
        _;
    }

    modifier onlyUser(string memory _name){
        require(verifyAddress.checkTargetSenderGroup(_name, msg.sender), "Only FoundationManager can use this function.");
        _;
    }

    //Set the related OSM contract address
    function setOSM(address _add)public onlyUser("FoundationManager") returns(bool){
        queryData = OSMInterface(_add);
        return true;
    }

    //Set the related governance contract address
    function setGovernance(address _add)public onlyUser("FoundationManager") returns(bool result){
        verifyAddress = governanceInterface(_add);
        return true;
    }

    receive () external payable{}

    //Get the total circulation of USTN
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    //Query the USTN balance of the specified tokenOwner account
    function balanceOf(address tokenOwner) external view override returns (uint256 balance) {
        return _balance[tokenOwner];
    }
    
    //Give to address, the USTN of the number of tokens
    function transfer(address to, uint256 tokens) external override returns (bool result) {
	    require(_balance[msg.sender] > tokens, "USTN: balances not enough");
        _balance[msg.sender] -= tokens;
        _balance[to] += tokens;
        emit Transfer(msg.sender, to, tokens);
        
        return true;
    }
    
    // The remaining number of tokens authorized to spender by the tokenowner
    function allowance(address tokenOwner, address spender) external view override returns (uint256 remaining) {
        return _approve[tokenOwner][spender];
    }
  
    // tokenOwner delegate spender use tokens
    function approve(address spender, uint256 tokens) external override returns (bool success) {
        _approve[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // transfer tokens from >> to
    function transferFrom(address from, address to, uint256 tokens) external override returns (bool success) {
        _approve[from][msg.sender] -= tokens;
        _balance[from] -= tokens;
        _balance[to] += tokens;
        emit Transfer(from, to, tokens);
        return true;
    }

    //Only allow USTNAuction contract to use
    //require to get the account address of AuctionManager
    //bider to AuctionManager, amount of USTN
    function bidCost(address bider, uint amount)public onlyContract("USTNAuction") returns(bool){
        require(_balance[bider] > amount, "USTN: balances not enough");
        require(queryAuctionManager() != address(0), "USTN: zero address");
        _balance[bider] -= amount;
        _balance[queryAuctionManager()] += amount;
        
        
        return true;
    }

    //Only allow USTNAuction contract to use
    //require to get the account address of AuctionManager
    //AuctionManager returns to bider, the amount of USTN
    function bidBack(address bider, uint amount)public onlyContract("USTNAuction") returns(bool){
        require(bider != address(0), "USTN: zero address");
        require(queryAuctionManager() != address(0), "USTN: zero address");
        _balance[bider] += amount;
        _balance[queryAuctionManager()] -= amount;
        return true;
    }

    //Query the address of AuctionManager
    function queryAuctionManager()public view returns(address){
        return verifyAddress.getAddress("AuctionManager");
    }

    //Only allow USTNFinance to use
    //Reduce the total amount issued by the amount
    //Repay the loan to reduce the bank's additional issuance
    function reduceTotalSupply(uint amount)public onlyContract("USTNFinance") returns(bool){
        _totalSupply -= amount;

        return true;
    }

    //Only allow USTNFinance to use
    //Increase the total amount issued by the amount
    //The loan interest causes the total issuance to increase
    function addTotalSupply(uint amount)public onlyContract("USTNFinance") returns(bool){
        _totalSupply += amount;

        return true;
    }

    // Only allow USTNFinance to use
    //Increase the add address, the amount of USTN
    function addBalance(address add, uint amount)public onlyContract("USTNFinance") returns(bool){
        _balance[add] += amount;

        return true;
    }

    // Only allow USTNFinance to use
    //Reduce add address, amount of USTN
    function reduceBalance(address add, uint amount)public onlyContract("USTNFinance") returns(bool){
        _balance[add] -= amount;

        return true;
    }
    
    //Based on the currency price of OSM, get the ratio of USTN to UNIT
    function mintRate(uint256 amount)public view returns(uint256){
        return getOSMValue(unit) * amount / getOSMValue(ustn);
    }

    //Based on the currency price of OSM, get the proportion of UNIT repurchasing USTN
    function mintBackRate(uint256 amount)public view returns(uint256){
        return getOSMValue(ustn) * amount / getOSMValue(unit);
    }

    //Based on the OSM ratio, exchange the USTN of the msg.value value
    function mint()public payable returns(bool result){
        uint exchange_tokens = mintRate(msg.value);
        require(exchange_tokens + _totalSupply <= 5*10**26, "overflow");
        _totalSupply += exchange_tokens;
        _balance[msg.sender] += exchange_tokens;

        emit convert(block.timestamp, msg.sender, msg.value, exchange_tokens, "mint");
        emit Transfer(address(0), msg.sender, exchange_tokens);
        return true;
    }

    //Based on the proportion of OSM, repurchase the UNIT of the token value
    function mintBack(uint256 tokens) public payable returns(bool){
        require(_totalSupply > 5*10**26);
        require((_totalSupply - 5*10**26) *getOSMValue(unit) /getOSMValue(ustn) >= tokens, "overflow the mintbak threshold");
        uint exchange_tokens = mintBackRate(tokens);
        _balance[msg.sender] -= tokens;
        _totalSupply -= tokens;
        payable(msg.sender).transfer(exchange_tokens);

        emit convert(block.timestamp, msg.sender, tokens, exchange_tokens, "mintBack");
        return true;
    }
    
    //only allowed for USTNAuction
    //Triggered when receiving the auction item, burns the number of tokens of AuctionManager
    function burn(address account, uint256 tokens) public onlyContract("USTNAuction") returns (bool) {
        require(tokens <= _balance[account], "USTN: balance not enough" );
        _totalSupply -= tokens;
        _balance[account] -= tokens;
        
        emit Transfer(account, address(0), tokens);
        return true;
    }

    //query OSM value internal function 
    function getOSMValue(string memory currencyName)internal view returns(uint){
        require(queryData.getCurrencyValue(currencyName)>0, "USTN: value must bigger than zero");
        return queryData.getCurrencyValue(currencyName);
    }
   
}

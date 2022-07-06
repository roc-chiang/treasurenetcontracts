// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "contracts/IERC20.sol";
import "contracts/governanceInterface.sol";

interface use_expense{
    function queryAccountData(address account)pure external returns(uint256 Margin, uint256 Symbol);
}

interface use_treasure{
    function getProductData(uint month, string memory UWI, string memory mineralType) view external returns (uint256 price, uint status);
    function stateUpdate(uint month, string memory UWI, string memory mineralType)external returns(bool);
}

contract TAT is IERC20 {

    event TATHistory(uint date, address producer, uint _type, string content, uint amount);
    
    string public constant name = "TAT token";
    uint8 public constant decimals = 18;
    string public constant symbol = "TAT";
    uint256 public _totalSupply;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _approve;
    mapping (address => bool) minters;

    governanceInterface verifyAddress;
    use_expense queryMargin;
    use_treasure queryData;

    
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

    //Set the related treasure contract address
    function setTreasure(address _add)public onlyUser("FoundationManager") returns(bool){
        queryData = use_treasure(_add);
        return true;
    }

    //Set the related expense contract address
    function setExpense(address _add)public onlyUser("FoundationManager") returns(bool result){
        queryMargin = use_expense(_add);
        return true;
    }

   //Set the related governance contract address
    function setGovernance(address _add)public onlyUser("FoundationManager") returns(bool result){
        verifyAddress = governanceInterface(_add);
        return true;
    }

    function totalSupply() external view override returns (uint256){
        return _totalSupply;
    }
    
    function balanceOf(address tokenOwner) external view override returns (uint256 balance){
        return _balances[tokenOwner];
    }
    
    function transfer(address to, uint256 tokens) external override returns (bool result){
        require(_balances[msg.sender] >= tokens );
        _balances[msg.sender] -= tokens;
        _balances[to] += tokens;
        emit Transfer(msg.sender, to, tokens);
        emit TATHistory(block.timestamp, msg.sender, 2, "transfer", tokens);
        emit TATHistory(block.timestamp, to, 1, "transfer", tokens);
        return true;
    }
    
    // The remaining number of tokens authorized to spender by the tokenowner
    function allowance(address tokenOwner, address spender) external view override returns (uint256 remaining){
        return _approve[tokenOwner][spender];
    }
  
    // tokenOwner delegate spender use tokens
    function approve(address spender, uint256 tokens) external override returns (bool success) {
        _approve[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // transfer tokens from >> to
    function transferFrom(address from, address to, uint256 tokens) external override returns (bool success){
        _approve[from][msg.sender] -= tokens;     
        _balances[from] -= tokens;
        _balances[to] += tokens;
        emit Transfer(from, to, tokens);
        return true;
    }

    //Only used by the Treasure contract
    //Give the account user TAT reward
    function mintReward(address account, uint value, string memory _type)public onlyContract("Treasure") returns(bool){
        _totalSupply += value;
        _balances[account] += value;

        emit TATHistory(block.timestamp, account, 1, _type, value);
        
        return true;
    }

    //The producer calls the resource production TAT for the audited month date
    function mintTATManufacturer(uint month, string memory UWI, string memory mineralType)public returns (bool){
        require(verifyAddress.checkUWIOwnerAddress(UWI,msg.sender), "UWI not yours");
        ( , uint manufacturerMarginSymbol) = queryMargin.queryAccountData(msg.sender); 
        require(manufacturerMarginSymbol == 1, "abnormal margin status"); 
        (uint marketValue, uint auditState) = queryData.getProductData(month, UWI, mineralType);
        require(auditState == 1, "not audited by auditor");
        require(queryData.stateUpdate(month,UWI,mineralType), "update status failed");
        _totalSupply += marketValue*10**18;
        _balances[msg.sender] += marketValue*10**18;

        emit Transfer(address(0), msg.sender, marketValue);
        emit TATHistory(block.timestamp, msg.sender, 1, "OIL", marketValue*10**18);
        return true;
    }

    //Only for Auditor users
    //To account users, produce TAT for month date
    function mintTATSystem(address account, uint month, string memory UWI, string memory mineralType)public onlyUser("Auditor")returns (bool){
        require(verifyAddress.checkUWIOwnerAddress(UWI,account), "UWI not yours");
        ( , uint manufacturerMarginSymbol) = queryMargin.queryAccountData(account); 
        require(manufacturerMarginSymbol == 1, "abnormal margin status"); 
        (uint marketValue, uint auditState) = queryData.getProductData(month, UWI, mineralType);
        require(auditState == 1, "not audited by auditor");
        require(queryData.stateUpdate(month,UWI,mineralType), "update status failed");
        _totalSupply += marketValue*10**18;
        _balances[account] += marketValue*10**18;

        emit Transfer(address(0), account, marketValue);
        emit TATHistory(block.timestamp, account, 1, "OIL", marketValue*10**18);
        return true;
    }

    //Only used by Bid contract
    //Burn when the proposer is successfully selected through the bid contract
    function burn(uint256 tokens)public onlyContract("Bid") returns (bool){
        _totalSupply -= tokens;

        emit Transfer(msg.sender, address(0), tokens);
        return true;
    }

    //Only used by Bid contract
    //spend TAT when campaigning for proposer through the bid contract
    function bidCost(address account, uint tokens)public onlyContract("Bid") returns(bool result){
        require(_balances[account] >= tokens, "TAT is not enough");
        _balances[account] -= tokens;
        emit TATHistory(block.timestamp, account, 2, "bid", tokens);
        return true;
    }

    //Only used by Bid contract
    //Return the mortgaged TAT when the bid contract is passed and the campaign proposer fails
    function bidBack(address account,uint tokens)public onlyContract("Bid") returns(bool result){
        _balances[account] += tokens;
        emit TATHistory(block.timestamp, account, 1, "bid", tokens);
        return true;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;
import "contracts/governanceInterface.sol";

contract expense{

    event expenseHistory(uint time, address operator, uint _type, string content, uint256 tokens);
    
    receive () external payable{}
    mapping(address => uint) manufacturerMargin;
    mapping(address => address) debtor;
    mapping(address => uint) marginSymbol;
    mapping(address => bool) manufacturer;
    address[] manufactureList;

    governanceInterface verifyAddress;

    constructor(address governanceAddress){
        verifyAddress = governanceInterface(governanceAddress);
    }

    modifier onlyFoundationManager(){
        require(verifyAddress.checkTargetSenderGroup("FoundationManager", msg.sender), "Only FoundationManager can use this function.");
        _;
    }

    modifier onlyTreasureContract() {
        require(verifyAddress.checkTargetSenderContractGroup("Treasure", msg.sender), "Only Treasure Contract");
        _;
    }

    //set governance contract address
    function setGovernance(address _add)public onlyFoundationManager returns(bool result){
        verifyAddress = governanceInterface(_add);
        return true;
    }

    //conclude Manufacturer in the list
    function isManufacturer(address Addr)internal view returns(bool){
        return manufacturer[Addr];
    }
    
    //预缴纳功能，用户提前预缴UNIT作为保证金
    function prepaid() public payable returns(bool result){
        require(msg.value>0, "payment must bigger than zero");
        if(!isManufacturer(msg.sender)){
            manufacturer[msg.sender] = true;
            manufactureList.push(msg.sender);
        }
        if(marginSymbol[msg.sender] !=2){
            manufacturerMargin[msg.sender] += msg.value;
            marginSymbol[msg.sender] = 1;
        }else if(marginSymbol[msg.sender] ==2){
            if(manufacturerMargin[msg.sender] > msg.value){
                manufacturerMargin[msg.sender] -= msg.value;
                payable(debtor[msg.sender]).transfer(msg.value);
            }else{
                manufacturerMargin[msg.sender] = msg.value - manufacturerMargin[msg.sender];
                marginSymbol[msg.sender] = 1;
                payable(debtor[msg.sender]).transfer(manufacturerMargin[msg.sender]);
            }
        }  

        emit expenseHistory(block.timestamp, msg.sender, 1, "deposite", msg.value);

        return true;
    }
    
    //查询account用户的预缴信息和状态
    function queryAccountData(address account)public view returns(uint256 Margin, uint256 Symbol){
        return (manufacturerMargin[account], marginSymbol[account]);
    }
    
    //从保证金存款里提取amount数量的UNIT
    function extract(uint256 amount)public payable returns(bool){
        require(manufacturer[msg.sender], "you are not manufacturem");
        require(marginSymbol[msg.sender] == 1, "abnormal margin status");
        require(manufacturerMargin[msg.sender] >= amount, "margin is not enough");
        manufacturerMargin[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);

        emit expenseHistory(block.timestamp, msg.sender, 2, "extract", amount);

        return true;
    }
    
    //仅限treasure合约触发惩罚
    //基于account用户，value，以及percent，根据公式算出惩罚金额
    function penalty(address account, uint value, uint percent)public onlyTreasureContract returns(bool){
        require(marginSymbol[account]==1, "Expense: balance already negative");
        address auditor = verifyAddress.getAddress("Auditor");
        uint penaltyCost = value *percent *verifyAddress.getMarginRatio() /1000000;

        if(manufacturerMargin[account] >= penaltyCost){
            manufacturerMargin[account] -= penaltyCost;
            payable(auditor).transfer(penaltyCost);
        }else{
            payable(auditor).transfer(manufacturerMargin[account]);
            manufacturerMargin[account] = penaltyCost - manufacturerMargin[account];
            marginSymbol[account] = 2;
            debtor[account] = auditor;

        }

        emit expenseHistory(block.timestamp, account, 3, "penalty", penaltyCost);

        return true;
    }

    //仅限treasure合约触发惩罚
    //基于account用户的数字资产以及value，根据公式算出惩罚金额
    function mintPenalty(address account, uint value, uint _type)public onlyTreasureContract returns(bool){
        require(marginSymbol[account]==1, "Expense: balance already negative");
        address auditor = verifyAddress.getAddress("Auditor");
        if(manufacturerMargin[account] >= value){
            manufacturerMargin[account] -= value;
            payable(auditor).transfer(value);
        }else{
            payable(auditor).transfer(manufacturerMargin[account]);
            manufacturerMargin[account] = value - manufacturerMargin[account];
            marginSymbol[account] = 2;
            debtor[account] = auditor;
        }
        if(_type == 1){
            emit expenseHistory(block.timestamp, account, 4, "minePenalty", value);
        }else if(_type==2){
            emit expenseHistory(block.timestamp, account, 5, "minePenalty", value);
        }

        return true;
    }
    
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;
import "contracts/governanceInterface.sol";
interface TATInterface{
    function balanceOf(address tokenOwner) external view  returns (uint256 balance);
    function bidCost(address account, uint tokens)external returns(bool);
    function bidBack(address account,uint tokens)external returns(bool);
    function burn(uint256 tokens)external returns (bool);
}

contract bid{

    event bidResult(address _bider, string _type, string _result, uint _status, uint _amount);//_status, 1:return 2:expend
    event bidList(address account, uint256 amount);

    struct TATList{
        address bider;
        uint256 amount;
    }

    TATList[] public TATBiders;
    mapping(address => bool) isTATBid;
    uint bidMode = 1; //1:normol 2:auditor
    uint constant TATThreshold = 10**18;

    governanceInterface verifyAddress;
    TATInterface _tatContract;

    constructor(address governanceAddress) {
        verifyAddress = governanceInterface(governanceAddress);
    }

    modifier onlyFoundationManager(){
        require(verifyAddress.checkTargetSenderGroup("FoundationManager", msg.sender), "Only FoundationManager can use this function.");
        _;
    }
 
    //set governance address
    function setGovernance(address _add)public onlyFoundationManager returns(bool result){
        verifyAddress = governanceInterface(_add);
        return true;
    }

    receive () external payable{}


    //set TAT contract address
    function setTATContract(address contractAddress) public onlyFoundationManager returns(bool){
        _tatContract = TATInterface(contractAddress);
        return true;
    }

    function isTATBider(address pAddr)public view returns(bool result){
        return isTATBid[pAddr];
    }
    
    //bid TAT to a active validator
    function bidTAT(uint amount) public returns(bool result){
        require(bidMode == 1, "auditor is operation");
        require(amount >= TATThreshold, "TAT not enough to bid");
        require(_tatContract.balanceOf(msg.sender) >= amount, "TAT balance is not enough");
        require(_tatContract.bidCost(msg.sender, amount), "bid cost failed");
        if(!isTATBider(msg.sender)){
            isTATBid[msg.sender]=true;
        }
        TATList memory b;
        b.bider = msg.sender;
        b.amount += amount;
        TATBiders.push(b);
        return true;
    }

    function getList()public view returns(TATList[] memory){
        
        TATList[] memory list = TATBiders;
        //delete
        return list;
    }
    //reset algorithm
    function deleteData()internal returns(bool){
        for(uint a=0; a<TATBiders.length; a++){
            //delete isTATBid[TATBiders[a]];
        }

        delete TATBiders;

        return true;
    }

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import "contracts/OSMInterface.sol";
import "contracts/governanceInterface.sol";

interface TATInterface{
    function mintReward(address account, uint value, string memory _type) external returns(bool);
}

interface expenseInterface{
    function mintPenalty(address account, uint value, uint _type)external returns(bool);
    function penalty(address account, uint value, uint percent)external returns(bool);
    function queryAccountData(address account)external view returns(uint256 Margin, uint256 Symbol);

}

contract treasureData {

    event comptroller(address operator, string _type, string UWI, uint contentTime, uint deviation, uint yield, uint value, uint id, uint status);
    event productAdd(address operator, string _type, uint dataTime, string UWI, uint deviation, uint deducted, uint value, string result);

    struct _product {
        address account;
        string UWI;
        string mineralType;
        uint256 amount;
        uint256 price;
        uint uniqueID;
        uint status;
    }

    struct dataMint {
        address _miner;
        string _type;
        uint blockNumber;
        uint _value;
        uint _timestamp;
        uint uniqueID;
        uint status;
    }

    mapping(address =>uint []) blockData;
    mapping(uint => _product[]) productData;
    mapping(uint => dataMint[]) userData;
    mapping (address => bool) _mintUser;

    uint constant AUDITED = 1;
    uint constant UNAUDITED = 2;
    uint constant FINISHED = 3;
    uint constant FAILED = 4;

    uint dataCount = 0;
    uint entityCount = 0;
    governanceInterface _governanceContract;
    OSMInterface _oracleContract;
    TATInterface _tatContract;
    expenseInterface _expenseContract;

    constructor(address governanceAddress) {
        _governanceContract = governanceInterface(governanceAddress);
    }

    modifier onlyUser(string memory name){
        require(_governanceContract.checkTargetSenderGroup(name, msg.sender), "Only Authority User can use this function.");
        _;
    }

    modifier onlyProducerAddress(){
        require(_governanceContract.checkProducerAddress(msg.sender), "Only audited Producer can upload your product amount.");
        _;
    }

    modifier onlyTAT(){
        require(_governanceContract.checkTargetSenderContractGroup("TAT", msg.sender), "Only TAT Contract can use this interface.");
        _;
    }

    modifier onlyMiner(string memory name){
        require(keccak256(bytes(_governanceContract.getMinerAddress(msg.sender, name))) != keccak256(bytes(" ")), "Only miner can use this interface.");
        _;
    }

    //Set the related governance contract address
    function setGovernanceContract(address contractAddress) public onlyUser("FoundationManager") returns(bool){
        _governanceContract = governanceInterface(contractAddress);
        return true;
    }

    //Set the related OSM contract address
    function setOracleContract(address contractAddress) public onlyUser("FoundationManager") returns(bool){
        _oracleContract = OSMInterface(contractAddress);
        return true;
    }

    //Set the related TAT contract address
    function setTATContract(address contractAddress) public onlyUser("FoundationManager") returns(bool){
        _tatContract = TATInterface(contractAddress);
        return true;
    }

    //Set the related expense contract address
    function setExpenseContract(address contractAddress) public onlyUser("FoundationManager") returns(bool){
        _expenseContract = expenseInterface(contractAddress);
        return true;
    }

    //Add production data to producers who have registered ProducerAddress in government
    function addProductData(uint month, string memory location, string memory location_id, string memory mineralType, uint256 amount, uint date) public onlyProducerAddress returns (bool){
        string memory UWI = _governanceContract.getUWI(msg.sender, location_id, location);
        uint256 price = amount * _oracleContract.getResourceValue(mineralType, date) * _governanceContract.getPriceDiscount(msg.sender, UWI)/ 10000;
        bool _exist = false;
        for (uint i = 0; i < productData[month].length; i++) {
            if (keccak256(bytes(productData[month][i].UWI)) == keccak256(bytes(UWI)) && keccak256(bytes(productData[month][i].mineralType)) == keccak256(bytes(mineralType))) {
                _exist = true;
                if (productData[month][i].status == UNAUDITED) {
                    productData[month][i].amount = productData[month][i].amount + amount;
                    productData[month][i].price = productData[month][i].price + price;
                }
                else {
                    revert("Cannot update output information for a data that has been audited.");
                }
            }
        }
        if (!_exist) {
            _product memory p;
            p.account = msg.sender;
            p.UWI = UWI;
            p.mineralType = mineralType;
            p.amount = amount;
            p.price = price;
            p.uniqueID = entityCount;
            p.status = UNAUDITED;
            productData[month].push(p);
        }

        //emit comptroller(msg.sender, mineralType, UWI, month, 0, amount, price, entityCount, UNAUDITED);
        
        entityCount++;

        return true;
    }
    
    function isMinter(address _add)internal view returns(bool){
        return _mintUser[_add];
    }

    //Users who have bound addresses in government can add digital assets
    //date: yyyymmdd, number: blockHeight
    function addMintData(string memory typeName, uint number, uint date, uint month)public onlyMiner(typeName) returns(bool){
        if(!isMinter(msg.sender)){
            _mintUser[msg.sender] = true;
        }
        for(uint a=0; a < blockData[msg.sender].length; a++){
            if(blockData[msg.sender][a] == number){
                revert("block number already exist");
            }
        }

        blockData[msg.sender].push(number);
        
        dataMint memory d;
        d._miner = msg.sender;
        d._type = typeName;
        d.blockNumber = number;
        d._value = 6 *_oracleContract.getResourceValue(typeName, date) *10**18;
        d._timestamp = block.timestamp;
        d.uniqueID = dataCount;
        d.status = UNAUDITED;
        userData[month].push(d);

        emit comptroller(msg.sender, typeName, "0", month, 0, number, userData[month][userData[month].length-1]._value, dataCount, userData[month][userData[month].length-1].status);

        dataCount ++;

        return true;
    }

    //Get all data asset data of unaudited date
    function getUnauditedMintData(uint month)public view returns(dataMint[] memory){
        dataMint[] memory dataMintList = new dataMint[](userData[month].length);
        uint j = 0;
        for (uint i = 0; i < userData[month].length; i++) {
            ( , uint status)=_expenseContract.queryAccountData(userData[month][i]._miner);
            if (userData[month][i].status == UNAUDITED && status ==1) {
                dataMintList[j] = userData[month][i];
                j++;
            }else{
                dataMintList[j] = dataMint(address(0), "0", 0, 0, 0, 0, 0);
                j++;
            }
        }

        return dataMintList;
    }

    //Auditor audits whether the data assets on the date are true
    //Update state and generate TAT or penalty
    function updateMintData(uint date, uint number, bool result)public onlyUser("Auditor") returns(bool){
        if(result == true){
            userData[date][number].status = AUDITED;
            _tatContract.mintReward(userData[date][number]._miner, userData[date][number]._value, userData[date][number]._type);
            emit comptroller(userData[date][number]._miner, userData[date][number]._type, "0", date, 0, userData[date][number].blockNumber, userData[date][number]._value, userData[date][number].uniqueID, userData[date][number].status);
        }else if(result == false){
            userData[date][number].status = FAILED;
            uint cost = userData[date][number]._value /1000;
            if(keccak256(bytes(userData[date][number]._type)) == keccak256(bytes("ETH"))){
                _expenseContract.mintPenalty(userData[date][number]._miner, cost, 1);
            }else if(keccak256(bytes(userData[date][number]._type)) == keccak256(bytes("BTC"))){
                _expenseContract.mintPenalty(userData[date][number]._miner, cost, 2);
            }

            emit comptroller(userData[date][number]._miner, userData[date][number]._type, "0", date, cost, 0, userData[date][number].blockNumber, userData[date][number].uniqueID, userData[date][number].status);
        }

        return true;
    }

    //Get the list of unaudited entity resources for month month
    function getUnauditedProductList(uint month) view public returns (_product[] memory){
        uint resultCount = 0;
        for (uint i = 0; i < productData[month].length; i++) {
            ( , uint status)=_expenseContract.queryAccountData(productData[month][i].account);
            if (productData[month][i].status == UNAUDITED && status ==1) {
                resultCount++;
            }
        }
        _product[] memory productList = new _product[](resultCount);
        uint j = 0;
        for (uint i = 0; i < productData[month].length; i++) {
            ( , uint status)=_expenseContract.queryAccountData(productData[month][i].account);
            if (productData[month][i].status == UNAUDITED && status ==1) {
                productList[j] = productData[month][i];
                j++;
            }
        }
        return productList;
    }

    //Get month month, based on the price and audit status corresponding to UWI and mineralType
    function getProductData(uint month, string memory UWI, string memory mineralType) view public returns (uint256 price, uint status){
        bool _exist = false;
        for (uint i = 0; i < productData[month].length; i++) {
            if (keccak256(bytes(productData[month][i].UWI)) == keccak256(bytes(UWI)) && keccak256(bytes(productData[month][i].mineralType)) == keccak256(bytes(mineralType))) {
                _exist = true;
                price = productData[month][i].price;
                status = productData[month][i].status;
            }
        }
        if (_exist) {
            return (price, status);
        }else {
            revert("The queried or updated output data information does not exist, please check the retrieval conditions.");
        }
    }

    //Auditor audit month month, based on UWI and MineralType, compared to amount
    //Update the status after the audit, and determine whether to trigger the penalty
    function updateProductData(uint month, string memory UWI, string memory mineralType, uint256 amount) public onlyUser("Auditor") returns(bool){
        for (uint i = 0; i < productData[month].length; i++) {
            if (keccak256(bytes(productData[month][i].UWI)) == keccak256(bytes(UWI)) && keccak256(bytes(productData[month][i].mineralType)) == keccak256(bytes(mineralType))) {
                _updateProductData(month,i,amount);
            }    
        }
        return true;
    }

    function _updateProductData(uint month, uint i, uint amount)internal returns(bool){
        if (productData[month][i].amount > amount) {
                uint256 nprice = productData[month][i].price * amount / productData[month][i].amount;
                productData[month][i].amount = amount;
                productData[month][i].price = nprice;
                productData[month][i].status = AUDITED;
                uint deviation = (productData[month][i].amount - amount)*100 /amount;
                if(10 < deviation && deviation <= 30){
                    _expenseContract.penalty(productData[month][i].account, nprice, deviation);
                }else if (deviation >30){
                    _expenseContract.penalty(productData[month][i].account, nprice, 100);
                }
                _product memory k = productData[month][i];
                emit comptroller(k.account, k.mineralType, k.UWI, month, deviation, amount, nprice, k.uniqueID, k.status);
        }else{
                productData[month][i].status = AUDITED;
                emit comptroller(productData[month][i].account, productData[month][i].mineralType, productData[month][i].UWI, month, 0, productData[month][i].amount, productData[month][i].price, productData[month][i].uniqueID, productData[month][i].status);
        }

        return true;
    }

    //After manufacturing TAT, update the status to prevent repeated manufacturing
    function stateUpdate(uint month, string memory UWI, string memory mineralType)public onlyTAT returns(bool){
        for (uint i = 0; i < productData[month].length; i++) {
            if (keccak256(bytes(productData[month][i].UWI)) == keccak256(bytes(UWI)) && keccak256(bytes(productData[month][i].mineralType)) == keccak256(bytes(mineralType))) {
                productData[month][i].status = FINISHED;
                emit comptroller(productData[month][i].account, productData[month][i].mineralType, productData[month][i].UWI, month, 0, productData[month][i].amount, productData[month][i].price, productData[month][i].uniqueID, productData[month][i].status);
            }        
        }  
        return true;
    }

}

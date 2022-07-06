// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

contract governance {

    struct priceDiscountConfig {
        uint API;
        uint sulphur;
        uint[4] discount;
    }

    priceDiscountConfig _priceDiscountConfig;

    struct mineData {
        string location_id;
        string location;
        string UWI;
        uint API;
        uint sulphur;
        bool status;
    }

    mapping(address => string) ethAddress;
    mapping(address => string) btcAddress;

    mapping(string => address) _userGroup; //user group

    mapping(string => address) _contractGroup; //contract group

    mapping(string => uint) _platformConfig; //platform config

    mapping(address => mineData[]) producerData; //producer data;

    mapping(address => bool) producerStatus;

    string[] _mineralType;

    uint warnRatio = 9900;

    uint liquidationRatio = 9000;

    constructor(address FM){
        _userGroup["FoundationManager"] = FM;
        // 生产商保证金缴纳比例  Margin Ratio 
        _platformConfig["marginRatio"] = 100;
        // USTN准备金率 USTN reserve ratio 
        _platformConfig["reserveRatio"] = 1000;
        // USTN贷款日利率 USTN loan daily interest rate 
        _platformConfig["loanInterestRate"] = 5;
        // USTN贷款质押率 USTN loan pledge rate 
        _platformConfig["loanPledgeRate"] = 15000;
        _mineralType = ["OIL", "GAS"];
        // 油价折扣配置参数 
        _priceDiscountConfig.API = 3110;
        _priceDiscountConfig.sulphur = 500;
        _priceDiscountConfig.discount = [9000, 8500, 8000, 7500];

    }

    modifier onlyContractOrFM(string memory name){
        require( msg.sender == _userGroup["FoundationManager"]  || checkContract(name), "Only the FoundationManager or DAO contract");
        _;
    }

    modifier onlyUser(string memory level){
        require(checkUserGroup(level), "Insufficient permissions");
        _;
    }

    modifier onlyContract(string memory name){
        require(checkContract(name), "Insufficient permissions");
        _;
    }

    // check permission (from client) 
    function checkUserGroup(string memory level) view public returns (bool result){
        return checkTargetSenderGroup(level, msg.sender);
    }

    // check target sender permission (from otherContract) 
    function checkTargetSenderGroup(string memory level, address targetSender) view public returns (bool result){
        result = false;
            if (_userGroup[level] == targetSender) {
                result = true;
            }
        return result;
    }

    //check permission (from other contract)
    function checkContract(string memory name) view public returns (bool result){
        return checkTargetSenderContractGroup(name, msg.sender);
    }

    function checkTargetSenderContractGroup(string memory name, address contractAddress) view public returns (bool result){
        result = false;
        if (_contractGroup[name] == contractAddress) {
            result = true;
        }
        return result;
    }

    // Set user group. User group includes "FoundationManager", "Auditor", "Feeder" ，"AuctionManager"
    //Only allow DAO contract operations
    function setUserGroup(string memory level, address account) public onlyContractOrFM("DAO") returns(bool){
        _userGroup[level] = account;

        return true;
    }

    // set contract group. Contract group name includes "OSM","Treasure","Expense","USTN" && more
    //Only allow FoundationManager operations
    function setContractGroup(string memory name, address contractAddress) public onlyUser("FoundationManager") returns(bool) {
        require(_contractGroup[name] != contractAddress, "The new and old contractAddress are the same.");
        _contractGroup[name] = contractAddress;

        return true;
    }

    //set platform config params 
    //Only allow DAO contract operations ,passed vote
    function setPlatformConfig(string memory key, uint amount) public onlyUser("FoundationManager") returns(bool){
        if(keccak256(bytes(key)) == "marginRatio"){
            require(0 <=amount && amount <=10000,"overflow");
            _platformConfig[key] = amount;
        }else if(keccak256(bytes(key)) == "reserveRatio"){
            require(0 <=amount && amount <=10000,"overflow");
            _platformConfig[key] = amount;
        }else if(keccak256(bytes(key)) == "loanInterestRate"){
            require(0 <=amount && amount <=100,"overflow");
            _platformConfig[key] = amount;
        }else if(keccak256(bytes(key)) == "loanPledgeRate"){
            require(12000 <=amount && amount <=66600,"overflow");
            _platformConfig[key] = amount;
        }else if(keccak256(bytes(key)) == "liquidationRatio"){
            require(9000 <=amount && amount <=9900,"overflow");
            liquidationRatio = amount;
        }else{
            revert("not support");
        }

        return true;
    }

    // set price discount config params
    //Only allow DAO contract operations ,passed vote
    function setPriceDiscountConfig(uint API, uint sulphur, uint discount1, uint discount2, uint discount3, uint discount4) public onlyUser("FoundationManager") returns(bool) {
        require(0 <=API && API <=10000,"overflow");
        require(0 <=sulphur && sulphur <=10000,"overflow");
        require(0 <=discount1 && discount1 <=10000,"overflow");
        require(discount1 >discount2 && discount2 >discount3 && discount3 >discount4, "overflow");
        _priceDiscountConfig.API = API;
        _priceDiscountConfig.sulphur = sulphur;
        _priceDiscountConfig.discount = [discount1, discount2, discount3, discount4];

        return true;
    }

    // add type of minerals 
    //Only allow DAO contract operations ,passed vote
    function addMineralType(string memory newType) public onlyUser("FoundationManager") returns(bool) {
        bool exist = false;
        for (uint i = 0; i < _mineralType.length; i++) {
            if (keccak256(bytes(_mineralType[i])) == keccak256(bytes(newType))) {
                exist = true;
            }
        }
        if (exist) {
            revert("this mineral type is already exists.");
        }
        _mineralType.push(newType);

        return true;
    }

    // set producer data 
    //Only allow DAO contract operations ,passed vote
    function setProducerData(address account, string memory location_id, string memory location, string memory UWI, uint API, uint sulphur) public onlyUser("FoundationManager") returns(bool){
        mineData memory _data;
        _data.location_id = location_id;
        _data.location = location;
        _data.UWI = UWI;
        _data.API = API;
        _data.sulphur = sulphur;
        _data.status = true;
        bool exist = false;
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].UWI)) == keccak256(bytes(UWI))) {
                exist = true;
                // if exists -> update
                producerData[account][i] = _data;
            }
        }
        if (!exist) {
            // if not exist -> add
            producerData[account].push(_data);
        }

        return true;
    }

    function setProducerStatus(address account, string memory UWI, bool res)public onlyUser("FoundationManager") returns(bool){
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].UWI)) == keccak256(bytes(UWI))) {
                producerData[account][i].status = res;
            }
        }
        return true;
    }

    //set && binding digital asset user address and contract user address
    //Only allow FoundationManager operations
    function setMineAddress(string memory name, address userAdd, string memory mineAdd)public onlyUser("FoundationManager") returns(bool result){
        require((keccak256(bytes(name)) == keccak256(bytes("ETH"))) ||(keccak256(bytes(name)) == keccak256(bytes("BTC"))), "governance: only support BTC or ETH");
        require(keccak256(bytes(mineAdd)) != keccak256(bytes(" ")),"empty");
        if(keccak256(bytes(name)) == keccak256(bytes("ETH"))){
            ethAddress[userAdd] = mineAdd;
        }else if(keccak256(bytes(name)) == keccak256(bytes("BTC"))){
            btcAddress[userAdd] = mineAdd;
        }
        return true;

    }

    //Get the digital asset user address
    function getMinerAddress(address account, string memory name)public view returns(string memory){
        if(keccak256(bytes(name)) == keccak256(bytes("ETH"))){
            return ethAddress[account];
        }else if(keccak256(bytes(name)) == keccak256(bytes("BTC"))){
            return btcAddress[account];
        }else{
            return "0";
        }
         
    }

    //Check the digital asset user address
    function checkMinerAddress(address account, string memory name, string memory userAdd)public view returns(bool){
        if(keccak256(bytes(name)) == keccak256(bytes("ETH")) && keccak256(bytes(ethAddress[account]))== keccak256(bytes(userAdd))){
            return true;
        }else if(keccak256(bytes(name)) == keccak256(bytes("BTC")) && keccak256(bytes(btcAddress[account]))== keccak256(bytes(userAdd))){
            return true;
        }else{
            return false;
        }
    }

    // use account,location and location_id change UWI 
    function getUWI(address account, string memory location_id, string memory location) view public returns (string memory UWI){
        require(producerData[account].length > 0, "this producer address is not exist.");
        UWI = "";
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].location)) == keccak256(bytes(location)) && keccak256(bytes(producerData[account][i].location_id)) == keccak256(bytes(location_id))) {
                UWI = producerData[account][i].UWI;
            }
        }
        string memory empty = "";
        if (keccak256(bytes(UWI)) == keccak256(bytes(empty))) {
            revert("can not find this location & location_id");
        }
        else {
            return UWI;
        }
    }

    // get price discount 
    function getPriceDiscount(address account, string memory UWI) view public returns (uint discount){
        require(producerData[account].length > 0, "this producer address is not exist.");
        uint _API = 0;
        uint _sulphur = 0;
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].UWI)) == keccak256(bytes(UWI))) {
                _API = producerData[account][i].API;
                _sulphur = producerData[account][i].sulphur;
            }
        }
        if (_API == 0 || _sulphur == 0) {

            revert("this mine data is error or not exist this mine.");
        }
        //get discount
        if (_API > _priceDiscountConfig.API && _sulphur < _priceDiscountConfig.sulphur) {
            discount = _priceDiscountConfig.discount[0];
        }
        if (_API > _priceDiscountConfig.API && _sulphur >= _priceDiscountConfig.sulphur) {
            discount = _priceDiscountConfig.discount[1];
        }
        if (_API <= _priceDiscountConfig.API && _sulphur < _priceDiscountConfig.sulphur) {
            discount = _priceDiscountConfig.discount[2];
        }
        if (_API <= _priceDiscountConfig.API && _sulphur >= _priceDiscountConfig.sulphur) {
            discount = _priceDiscountConfig.discount[3];
        }
        return discount;
    }

    // get Margin Ratio 
    function getMarginRatio() view public returns (uint amount){
        return _platformConfig["marginRatio"];
    }


    // get USTN reserve ratio 
    function getUSTNReserveRatio() view public returns (uint amount){
        return _platformConfig["reserveRatio"];
    }

    // get USTN loan daily interest rate 
    function getUSTNLoanInterestRate() view public returns (uint amount){
        return _platformConfig["loanInterestRate"];
    }

    // get USTN loan pledge rate 
    function getUSTNLoanPledgeRate() view public returns (uint amount){
        return _platformConfig["loanPledgeRate"];
    }

    // get USTN loan pledge rate warning value 
    function getUSTNLoanPledgeRateWarningValue() view public returns (uint amount){
        return _platformConfig["loanPledgeRate"] *warnRatio /10000;
    }

    // get USTN loan liquidation rate 
    function getUSTNLoanLiquidationRate() view public returns (uint amount){
        return _platformConfig["loanPledgeRate"] *liquidationRatio /10000;
    }

    // check producer address available 
    function checkProducerAddress(address account) view public returns (bool result){
        result = false;
        if (producerData[account].length > 0) {
            result = true;

        }
        return result;
    }

    function checkUWIStatus(address account, string memory UWI)public view returns(bool res){
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].UWI)) == keccak256(bytes(UWI))) {
                return producerData[account][i].status;
                
            }
        }
    }

    // check UWI owner address 
    function checkUWIOwnerAddress(string memory UWI, address account) view public returns (bool result){
        result = false;
        for (uint i = 0; i < producerData[account].length; i++) {
            if (keccak256(bytes(producerData[account][i].UWI)) == keccak256(bytes(UWI))) {
                result = true;
            }
        }
        return result;
    }

    //Get the permission user address
    function getAddress(string memory name)public view returns(address){
        return _userGroup[name];
    }

    function getDiscount()public view returns(uint API, uint sulphur, uint d1, uint d2, uint d3, uint d4){
        return (_priceDiscountConfig.API, _priceDiscountConfig.sulphur, _priceDiscountConfig.discount[0], _priceDiscountConfig.discount[1], _priceDiscountConfig.discount[2], _priceDiscountConfig.discount[3]);
    }

    function getMineralType()public view returns(string[] memory){
        return _mineralType;
    }
}

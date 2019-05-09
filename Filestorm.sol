pragma solidity ^0.4.26;

// ----------------------------------------------------------------------------
// Precompiled contract executed by Moac MicroChain SCS Virtual Machine
// ----------------------------------------------------------------------------
contract Precompiled10 {
    function ipfsFile(string memory, uint, uint, string memory) public;
}

// ----------------------------------------------------------------------------
// Base contract that supports token usage in Dapp.
// ----------------------------------------------------------------------------
contract DappBase {
    struct RedeemMapping {
        address[] userAddr;
        uint[] userAmount;
        uint[] time;
    }

    struct Task {
        bytes32 hash;
        address[] voters;
        bool distDone;
    }

    struct EnterRecords {
        address[] userAddr;
        uint[] amount;
        uint[] time;
        uint[] buyTime;
    }

    RedeemMapping internal redeem;
    address[] public curNodeList;//
    mapping(bytes32 => Task) task;
    mapping(bytes32 => address[]) nodeVoters;
    address internal owner;
    EnterRecords internal enterRecords;
    uint public enterPos;
    constructor() public{
        owner = msg.sender;
    }

    function getCurNodeList() public view returns (address[] memory nodeList) {

        return curNodeList;
    }

    function getEnterRecords(address userAddr) public view returns (uint[] memory enterAmt, uint[] memory entertime) {
        uint i;
        uint j = 0;

        for (i = 0; i < enterPos; i++) {
            if (enterRecords.userAddr[i] == userAddr) {
                j++;
            }
        }

        uint[] memory amounts = new uint[](j);
        uint[] memory times = new uint[](j);
        j = 0;
        for (i = 0; i < enterPos; i++) {
            if (enterRecords.userAddr[i] == userAddr) {
                amounts[j] = enterRecords.amount[i];
                times[j] = enterRecords.time[i];
                j++;
            }
        }
        return (amounts, times);
    }

    function getRedeemMapping(address userAddr, uint pos) public view returns (address[] memory redeemingAddr, uint[] memory redeemingAmt, uint[] memory redeemingtime) {
        uint j = 0;
        uint k = 0;

        if (userAddr != address(0)) {
            for (k = pos; k < redeem.userAddr.length; k++) {
                if (redeem.userAddr[k] == userAddr) {
                    j++;
                }
            }
        } else {
            j += redeem.userAddr.length - pos;
        }
        address[] memory addrs = new address[](j);
        uint[] memory amounts = new uint[](j);
        uint[] memory times = new uint[](j);
        j = 0;
        for (k = pos; k < redeem.userAddr.length; k++) {
            if (userAddr != address(0)) {
                if (redeem.userAddr[k] == userAddr) {
                    amounts[j] = redeem.userAmount[k];
                    times[j] = redeem.time[k];
                    j++;
                }
            } else {
                addrs[j] = redeem.userAddr[k];
                amounts[j] = redeem.userAmount[k];
                times[j] = redeem.time[k];
                j++;
            }
        }
        return (addrs, amounts, times);
    }

    function redeemFromMicroChain() public payable {
        redeem.userAddr.push(msg.sender);
        redeem.userAmount.push(msg.value);
        redeem.time.push(now);
    }

    function have(address[] memory addrs, address addr) public view returns (bool) {
        uint i;
        for (i = 0; i < addrs.length; i++) {
            if (addrs[i] == addr) {
                return true;
            }
        }
        return false;
    }

    function updateNodeList(address[] memory newlist) public {
        //if owner, can directly update
        if (msg.sender == owner) {
            curNodeList = newlist;
        }
        //count votes
        bytes32 hash = sha3(newlist);
        bytes32 oldhash = sha3(curNodeList);
        if (hash == oldhash) return;

        bool res = have(nodeVoters[hash], msg.sender);
        if (!res) {
            nodeVoters[hash].push(msg.sender);
            if (nodeVoters[hash].length > newlist.length / 2) {
                curNodeList = newlist;
            }
        }

        return;
    }

    function postFlush(uint pos, address[] memory tosend, uint[] memory amount, uint[] memory times) public {
        require(have(curNodeList, msg.sender));
        require(tosend.length == amount.length);
        require(pos == enterPos);

        bytes32 hash = sha3(pos, tosend, amount, times);
        if (task[hash].distDone) return;
        if (!have(task[hash].voters, msg.sender)) {
            task[hash].voters.push(msg.sender);
            if (task[hash].voters.length > curNodeList.length / 2) {
                //distribute
                task[hash].distDone = true;
                for (uint i = 0; i < tosend.length; i++) {
                    enterRecords.userAddr.push(tosend[i]);
                    enterRecords.amount.push(amount[i]);
                    enterRecords.time.push(now);
                    enterRecords.buyTime.push(times[i]);
                    tosend[i].transfer(amount[i]);
                }
                enterPos += tosend.length;
            }
        }
    }
}

contract FileStormChain is DappBase {

    enum AccessType {read, write, remove, verify}

    using SafeMath for uint256;

    struct File {
        uint256 fileId;
        string fileHash;
        string fileName;
        uint256 fileSize;
        address fileOwner;
        uint256 createTime;
        uint256 verifiedCount;
    }

    struct Shard {
        uint256 shardId;
        uint nodeCount;
        uint256 weight;
        uint256 size;
        uint256 availableSize; // By byte.
        uint256 percentage; // Use 351234 for 0.351234
    }

    struct Node {
        uint256 shardId;
        address scsId;
        address beneficiary;
        uint256 size;
        uint256 lastVerifiedBlock;
    }

    struct VerifyTransaction {
        address scsId;
        address verifyNodeId;
        uint256 blockNumber;
        string fileHash;
        uint totalCount;
        uint votedCount;
        uint affirmCount;
    }

    uint blockVerificationInterval = 40;
    uint public shardSize = 10;
    uint256 awardAmount = 10000000000000000;  // coin

    address internal owner;
    mapping(address => uint) public admins;
    constructor() public payable{
        owner = msg.sender;
        capacityMapping[1] = 1024 * 1024 * 1024 * 1024;
        capacityMapping[2] = 1024 * 1024 * 1024 * 1024 * 2;
        capacityMapping[4] = 1024 * 1024 * 1024 * 1024 * 4;
        capacityMapping[8] = 1024 * 1024 * 1024 * 1024 * 8;
        capacityMapping[12] = 1024 * 1024 * 1024 * 1024 * 12;
        capacityMapping[16] = 1024 * 1024 * 1024 * 1024 * 16;
        capacityMapping[32] = 1024 * 1024 * 1024 * 1024 * 32;
    }

    function setCapacity(uint256 weight,uint256 size) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        capacityMapping[weight] = size;
    }

    function addAdmin(address admin) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        admins[admin] = 1;
    }

    function removeAdmin(address admin) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        admins[admin] = 0;
    }

    mapping(uint256 => uint256) public capacityMapping;

    mapping(uint256 => Shard) public shardMapping;
    uint256[] public shardList;
    uint256 public shardCount;
    uint256[] public recentlyUsedList;

    mapping(uint256 => File) public fileMapping;
    uint256[] public fileList;
    uint256 public fileCount;

    mapping(address => Node) public nodeMapping;
    address[] public unassignedNoteList;

    mapping(address => VerifyTransaction[]) public verifyGroupMapping;

    mapping(uint256 => address[]) public shardNodeList;

    mapping(address => uint256[]) private myFileList;
    mapping(uint256 => uint256[]) private shardFileList;
    mapping(uint256 => uint256) private fileShardIdMapping;

    mapping(address => Shard) public nodeShardMapping;

    Precompiled10 constant PREC10 = Precompiled10(0xA);

    // owner functions
    function setBlockVerificationInterval(uint num) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        blockVerificationInterval = num;
    }

    function setShardSize(uint size) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        shardSize = size;
    }

    function setAwardAmount(uint256 amount) public {
        require(msg.sender == owner || admins[msg.sender] == 1);
        awardAmount = amount;
    }

    function addShard(uint256 weight) public returns (uint256 shardId) {

        require(msg.sender == owner || admins[msg.sender] == 1);
        require(capacityMapping[weight]>0);
        shardId = shardList.length + 1;
        shardMapping[shardId].shardId = shardId;
        shardMapping[shardId].nodeCount = shardSize;
        shardMapping[shardId].weight = weight;
        shardMapping[shardId].size = capacityMapping[weight];
        shardMapping[shardId].availableSize = capacityMapping[weight];
        shardMapping[shardId].percentage = 0;
        shardList.push(shardId);

        // TO DO: select unassigned nodes and assign shard to them.
        // add all nodes to nodeShardMapping

//		if(shardList.length >1){
//			sortShardList(0, shardList.length-1);
//		}
        shardCount = shardList.length;
        return shardId;
    }

//    function removeShard(uint256 shardId) public returns (bool) {
//        require(msg.sender == owner || admins[msg.sender] == 1);
//        delete shardMapping[shardId];
//        return true;
//    }
    address[] nodeListTemp;
    uint256[] nodeListIndex;

    function addNode(address scsId, address beneficiary, uint256 weight) public returns (uint256)
    {
        require(nodeMapping[scsId].scsId == 0);
        require(capacityMapping[weight]>0);
        nodeMapping[scsId].scsId = scsId;
        nodeMapping[scsId].beneficiary = beneficiary;
        nodeMapping[scsId].size = capacityMapping[weight];
        nodeMapping[scsId].lastVerifiedBlock = 0;
        unassignedNoteList.push(scsId);

        nodeListTemp = new address[](shardSize);
        nodeListIndex = new uint256[](shardSize);
        uint index = 0;
        uint256 shardId = 0;
        for(uint i = 0;i<unassignedNoteList.length; i++){
            if(nodeListTemp[shardSize-1] != address(0)){
                break;
            }
            else{
                if(nodeMapping[unassignedNoteList[i]].size == capacityMapping[weight]){
                    nodeListTemp[index] = unassignedNoteList[i];
                    nodeListIndex[index]=i;
                    index++;
                }
            }
        }
        // 如果同weight的nodes的数量=shardSize
        if(index == shardSize){
            shardId = addShard(weight);
            // 把所有的nodes加到nodeShardMapping里面
            for(uint j=0; j<nodeListTemp.length; j++){
                nodeShardMapping[nodeListTemp[j]] = shardMapping[shardId];
                nodeMapping[nodeListTemp[j]].shardId = shardId;
                nodeMapping[nodeListTemp[j]].lastVerifiedBlock = block.number + blockVerificationInterval + j;
            }
            //在nodeList删除已经分配的node
            for(uint k=0; k<nodeListIndex.length; k++){
                removeFromAddressArray(nodeListIndex[k]);
            }
        }
        return shardId;
    }

    function removeNode(address scsId) public returns (bool)
    {
        require(msg.sender == owner || admins[msg.sender] == 1 || msg.sender == scsId || msg.sender == nodeMapping[scsId].beneficiary);
        delete nodeMapping[scsId];
        return true;
    }

    function addFile(string memory fileHash, string memory fileName, uint256 fileSize, uint256 createTime,uint256 shardId) public returns (uint256)
    {
        return addFile(fileHash, fileName, fileSize, createTime, "",shardId);
    }

    function addFile(string memory fileHash, string memory fileName, uint256 fileSize, uint256 createTime, string memory ipfsId,uint256 shardId) public returns (uint256)
    {
        require(shardList.length > 0);
        uint256 fileId = fileList.length + 1;

        File memory aFile;
        aFile.fileId = fileId;
        aFile.fileHash = fileHash;
        aFile.fileName = fileName;
        aFile.fileSize = fileSize;
        aFile.fileOwner = msg.sender;
        aFile.createTime = createTime;
        aFile.verifiedCount = 0;

        fileList.push(fileId);
        fileMapping[fileId] = aFile;

//        uint256 shardId = addToShard(aFile);
        // update shardMapping(shardId).availableSize and percentage from file info.
        shardMapping[shardId].availableSize = shardMapping[shardId].availableSize - aFile.fileSize;
        shardMapping[shardId].percentage = (10 ** 10) * (shardMapping[shardId].size - shardMapping[shardId].availableSize)/shardMapping[shardId].size;

        shardFileList[shardId].push(fileId);
        myFileList[msg.sender].push(fileId);
        fileShardIdMapping[fileId] = shardId;

        PREC10.ipfsFile(fileHash, uint(AccessType.write), shardId, ipfsId);
        fileCount = fileList.length;
        return (fileId);
    }

    function removeFile(uint256 fileId) public returns (bool)
    {
        require(msg.sender == fileMapping[fileId].fileOwner && fileMapping[fileId].fileId != 0);
        removeFromShard(fileMapping[fileId]);

        fileMapping[fileId].fileId = 0;
        delete fileMapping[fileId];

        PREC10.ipfsFile(fileMapping[fileId].fileHash, uint(AccessType.remove), fileShardIdMapping[fileId], "");

        return true;
    }

    function readFile(uint256 fileId, string memory ipfsId) public returns (bool)
    {

        PREC10.ipfsFile(fileMapping[fileId].fileHash, uint(AccessType.read), fileShardIdMapping[fileId], ipfsId);

        return true;
    }

    function addToShard(File memory aFile) private returns (uint256)
    {
        uint256 shardId = 1;
        // loop through list, should be sorted.
        // if availableSize < a.File.size, go to next.
        // if shard id in recentlyUsedList, go to next.
        for (uint i = 0; i < shardList.length; i++) {
            if (shardMapping[shardList[i]].availableSize < aFile.fileSize){
                continue;
            }
            bool result = recentlyUsed(shardList[i]);
            if(result == true){
                continue;
            }else{
                shardId = shardList[i];
                break;
            }
        }
        // update recentlyUsedList
        if (shardList.length > 10 && recentlyUsedList.length >= min(shardList.length.div(10), 10)){
            removeFromArray(0);
            recentlyUsedList.push(shardId);
        }else{
			if(shardList.length > 10){
			 recentlyUsedList.push(shardId);
			}
        }
        // update shardMapping(shardId).availableSize and percentage from file info.
        shardMapping[shardId].availableSize = shardMapping[shardId].availableSize - aFile.fileSize;
        shardMapping[shardId].percentage = (10 ** 10) * (shardMapping[shardId].size - shardMapping[shardId].availableSize)/shardMapping[shardId].size;
        // sort shard list by percentag
        if(shardList.length >1){
            sortShardList(0, shardList.length-1);
        }
        // return selected shardId
        return shardId;
    }

    function removeFromShard(File memory aFile) private
    {
        // TO DO: update shard information based on file removal.
    }

    function getMyFileHashes(address myAddr) view public returns (uint256[] memory) {
        return myFileList[myAddr];
    }

    function getAllFilesByShard(uint256 shardId) view public returns (uint256[] memory) {
        return shardFileList[shardId];
    }

    function getAllShards() view public returns (uint256[] memory) {
        return shardList;
    }

    function getFileById(uint256 fileId) view public returns (string memory , string memory, uint256, address, uint256, uint) {
        return (fileMapping[fileId].fileHash,
        fileMapping[fileId].fileName,
        fileMapping[fileId].fileSize,
        fileMapping[fileId].fileOwner,
        fileMapping[fileId].createTime,
        fileMapping[fileId].verifiedCount);
    }

    function submitVerifyTransaction(address verifyGroupId, address verifyNodeId, uint256 blockNumber, string memory fileHash, uint256 shardId) public {

        require(msg.sender == verifyNodeId);
        VerifyTransaction memory trans;
        trans.scsId = msg.sender;
        trans.verifyNodeId = msg.sender;
        trans.blockNumber = blockNumber;
        trans.fileHash = fileHash;
        trans.totalCount = shardMapping[shardId].nodeCount;
        trans.votedCount = 1;
        trans.affirmCount = 1;

        verifyGroupMapping[verifyGroupId].push(trans);
        nodeMapping[msg.sender].lastVerifiedBlock.add(blockVerificationInterval);
    }

    function voteVerifyTransaction(address verifyGroupId, address verifyNodeId, address votingNodeId, uint256 blockNumber,
        string memory fileHash, uint256 shardId) public returns (bool) {

        if(msg.sender != votingNodeId || verifyGroupMapping[verifyGroupId].length==0)
            return false;

        VerifyTransaction memory trans;
        trans.scsId = msg.sender;
        trans.verifyNodeId = verifyNodeId;
        trans.blockNumber = blockNumber;
        trans.fileHash = fileHash;
        trans.totalCount = verifyGroupMapping[verifyGroupId][0].totalCount;
        verifyGroupMapping[verifyGroupId][0].votedCount += 1;
        trans.votedCount = verifyGroupMapping[verifyGroupId][0].votedCount;

        if (compareStringsbyBytes(fileHash, verifyGroupMapping[verifyGroupId][0].fileHash)) {
            verifyGroupMapping[verifyGroupId][0].affirmCount += 1;
            trans.affirmCount = verifyGroupMapping[verifyGroupId][0].affirmCount;
        }

        verifyGroupMapping[verifyGroupId].push(trans);

        if (verifyGroupMapping[verifyGroupId][0].affirmCount > verifyGroupMapping[verifyGroupId][0].totalCount / 2)
        {
            address nodeId = verifyGroupMapping[verifyGroupId][0].scsId;
            address beneficiary = nodeMapping[nodeId].beneficiary;

            award(beneficiary);
        }
        return true;
    }

    function award(address beneficiary) public{
        // to do
    }

    function compareStringsbyBytes(string memory s1, string memory s2) private pure returns (bool)
    {
        bytes memory s1bytes = bytes(s1);
        bytes memory s2bytes = bytes(s2);
        if (s1bytes.length != s2bytes.length) {
            return false;
        }
        else {
            for (uint i = 0; i < s1bytes.length; i++)
            {
                if (s1bytes[i] != s2bytes[i])
                    return false;
            }
            return true;
        }
    }

    function removeFromArray(uint index) public {
        if (index >= recentlyUsedList.length)
            return;

        for (uint i = index; i < recentlyUsedList.length - 1; i++) {
            recentlyUsedList[i] = recentlyUsedList[i + 1];
        }
        delete recentlyUsedList[recentlyUsedList.length - 1];
        //array.length--;
    }

    function removeFromAddressArray( uint index) public{
        if (index >= unassignedNoteList.length)
            return;

        for (uint i = index; i < unassignedNoteList.length - 1; i++) {
            unassignedNoteList[i] = unassignedNoteList[i + 1];
        }
        delete unassignedNoteList[unassignedNoteList.length - 1];
        //array.length--;
    }

    function sortShardList(uint256 left, uint256 right) internal {
        uint256 i = left;
        uint256 j = right;
        uint256 pivot = left + (right - left) / 2;

        uint256 pivotValue = shardMapping[shardList[pivot]].percentage * shardMapping[shardList[pivot]].weight;
        while (i <= j) {
            while (shardMapping[shardList[i]].percentage * shardMapping[shardList[i]].weight < pivotValue) i++;
            while (pivotValue < shardMapping[shardList[j]].percentage * shardMapping[shardList[j]].weight) j--;
            if (i <= j) {
                (shardList[i], shardList[j]) = (shardList[j], shardList[i]);
                i++;
                j--;
            }
        }
        if (left < j)
            sortShardList(left, j);
        if (i < right)
            sortShardList(i, right);
    }

    function recentlyUsed(uint256 value) public returns (bool) {
        for (uint i = 0; i < recentlyUsedList.length; i++) {
            if (value == recentlyUsedList[i]) {
                return true;
            }
        }
        return false;
    }

    function min(uint256 val1,uint256 val2)public returns (uint256) {
        if(val1 <= val2){
            return val1;
        }else{
            return val2;
        }
    }
}



/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (_a == 0) {
            return 0;
        }

        uint256 c = _a * _b;
        require(c / _a == _b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b > 0);
        // Solidity only automatically asserts when dividing by 0
        uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b <= _a);
        uint256 c = _a - _b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 c = _a + _b;
        require(c >= _a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

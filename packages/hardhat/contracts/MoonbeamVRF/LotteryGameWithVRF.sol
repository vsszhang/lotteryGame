// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Randomness.sol";
import "./RandomnessConsumer.sol";

// TODO：
// 如果更换游戏轮次，记得清空delete游戏玩家的所有登记信息，同时清除VRF请求部分
// 开奖之后，betForLottery可以新增防止’开奖后执行锁‘🔒

contract LotteryGameWithVRF is RandomnessConsumer {
    // Lottery contract owner
    address public LOTTERY_OWNER;

    // Request randomness gas limit
    uint64 public RANDOMNESS_GAS_LIMIT = 100000;

    // Salt using in request randomness
    bytes32 public SALT_DEMO = bytes32("salt_demo");

    // Minimal block delay when request for local VRF pallet
    uint64 public MINI_BLOCK_DELAY = 2;

    // Minimal fee to execute fulfill random words
    uint256 public MINI_FEE = RANDOMNESS_GAS_LIMIT * 1 gwei;

    // Winning number
    uint256 public WINNING_NUMBER;

    // ID of request randomness
    uint256 public requestId;

    // Store random words
    uint256 public randomOutput;

    // whether bet for once or not
    mapping (address => bool) public bet4once;

    // Lottery player address => number value
    mapping (address => uint256) public accountToNumber;

    // Lottery player address => whether get reward
    mapping (address => bool) public accountToWin;

    // Get Randomness precompile contract instance
    Randomness constant randomness = Randomness(RANDOMNESS_ADDRESS);

    constructor() {
        LOTTERY_OWNER = msg.sender;
    }

    // ================= Contract Owner =================

    /// @dev Contract owner recharge token to reward pool (this contract)
    /// @dev （合约所有者）向合约奖池充值奖励token
    function rechargeToRewardPool() public payable onlyOwner {}

    /// @dev get reward pool balance
    /// @dev 获取奖池（合约本身）的奖金数量
    function getRewardPoolBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function requestRandomWords()
        public
        payable
        onlyOwner
    {
        require(
            msg.value > randomness.requiredDeposit() + MINI_FEE,
            "Deposit must larger than 1 DEV"
        );
        uint256 fee = msg.value - randomness.requiredDeposit();
        
        requestId = randomness.requestLocalVRFRandomWords(
            msg.sender,
            fee,
            RANDOMNESS_GAS_LIMIT,
            SALT_DEMO,
            1,
            MINI_BLOCK_DELAY
        );
    }

    function fulfillRequest()
        public 
        onlyOwner
    {
        randomness.fulfillRequest(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    )
        internal 
        override 
    {
        randomOutput = randomWords[0];
        lotteryDraw(randomOutput);
    }

    /// @dev Contract owner draw a lottery
    /// @dev 开奖！开奖！
    function lotteryDraw(uint256 randomNum)
        internal  
    {
        WINNING_NUMBER = randomNum % 10;
    }

    /// @dev Get all money back to contract owner account!!!
    /// @dev 还钱！还钱！退退退！！！
    function giveMyMoneyBack()
        external 
        onlyOwner
    {
        (bool success, ) = (msg.sender).call{value: getRewardPoolBalance()}("");
        require(success, ":-( my money cannot back to my hand!!!");
    }

    function nextRound() 
        external
        onlyOwner
    {
        
    }

    // ================= Lottery Player =================

    /// @dev Lottery player bet for their lottery
    /// @dev 为某一幸运数字下注（一人只有一次下注机会）
    function betForLottery(uint256 numberValue)
        public
        notOwner
        isBetOnce
    {
        accountToNumber[msg.sender] = numberValue;
        bet4once[msg.sender] = true;
    }

    /// @dev Lottery winner can get 1 ether Token as reward
    /// @dev 开奖确定赢家后，赢家可以从奖池获取 1 ether 数量的代币作为奖品
    function getReward()
        public 
        isWinner
    {
        require(
            getRewardPoolBalance() > 1 ether,
            ":-) pls contact with our contract owner, we do not have enough token"
        );
        (bool success, ) = (msg.sender).call{value: 1 ether}("");
        require(success, "Failed to send reward");
        accountToWin[msg.sender] = true;
    }



    modifier onlyOwner() {
        require(msg.sender == LOTTERY_OWNER, "U are not contract owner");
        _;
    }

    modifier notOwner() {
        require(msg.sender != LOTTERY_OWNER, "Onwer cannot participate");
        _;
    }

    modifier isWinner() {
        require(accountToNumber[msg.sender] == WINNING_NUMBER, "Bro, u are a fake winner~");
        _;
    }

    modifier isBetOnce() {
        require(bet4once[msg.sender] == false, "u are already bet, do not bet again");
        _;
    }

    receive() external payable {}
    fallback() external payable {}

}
// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract
// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.10;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title A sample Raffle Contract
 * @author Aman Gupta
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation
 */
contract Raffle is VRFConsumerBaseV2Plus{

    /** Error */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /** Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    
    uint16 private immutable i_callbackGasLimit;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_hashId;


    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;
    
    /** Events */
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address winner);


    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 hashKey, uint16 callbackGasLimit, uint256 subscriptionId) VRFConsumerBaseV2Plus(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_subscriptionId = subscriptionId;
        i_hashId = hashKey;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        
    }

    // 1. Get a winner
    // 2. Use the random number to pick a player
    // 3. Automatically called
    function pickWinner() external{
        // check to see if enough time has passed
        if(block.timestamp - s_lastTimeStamp < i_interval) revert();
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_hashId,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        

    }

    /** Getter Function */
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
        
    }
    function enterRaffle() external payable{
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function fulfillRandomWords(uint256 /*requestId/*/, uint256[] calldata randomWords) internal
    override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        (bool success,) = winner.call{value:address(this).balance}("");
        emit RaffleWinnerPicked(s_recentWinner);
        if(!success){
            revert Raffle__TransferFailed();
        }

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        

    }
}

/** Type Declarations */
enum RaffleState{
    OPEN, //0
    CALCULATING //1
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";

contract R8R is Ownable, ReentrancyGuard {
    // =========================
    // === STORAGE VARIABLES ===
    // =========================

    address public ai;
    uint256 public gameId;
    uint256 public gameEntryPriceInEth;
    uint256 public prizePool = address(this).balance;

    mapping(uint256 gameId => Game) games;

    // *** CHANGE TOKENALLOWLIST TO MAPPING ***
    // *** mapping(IERC20 allowedToken => tokenEntryPrice) public gameTokensToEntryPrice;
    mapping(IERC20 allowedToken => uint256 tokenEntryPrice) public gameTokensToEntryPrice;
    // IERC20[] public gameTokensAllowedList; // list of ERC20 tokens users can use to enter the game
    // uint256[] public gameTokensEntryPriceList; // list of entry price for the ERC20 tokens

    struct Game {
        uint256 gameId;
        address[] playerKeys;
        mapping(address => uint256) playerAddressesToRatings;
        uint256 numberOfPlayersInGame;
        uint256 aiRating;
        address[] winners;
        uint256 winnerPayout;
        uint256 gameBalance;
        bool gameEnded;
    }

    // ==============
    // === EVENTS ===
    // ==============

    event GameCreated(uint256 indexed gameId, uint256 endTimestamp, uint256 gameEntryFee, uint256 prizePool);
    // *** REFACTOR JOINEDGAMES TO ONE EVENT ***
    // DONE!! event PlayerJoinedGame(address indexed player, uint256 indexed gameId, uint256 playerRating); <<< this, but fix in logic too
    event PlayerJoinedGame(address indexed player, uint256 indexed gameId, uint256 playerRating, address token); // emit token address too (address(0) if they use ETH)
    event GameEnded(address[] indexed winners, uint256 payoutPerWinner, uint256 indexed gameId);

    // ==============
    // === ERRORS ===
    // ==============
    error Error__TokenTransferFailed();
    error Error__JoinWithEitherTokensOrEthNotBoth();

    // ===================
    // === CONSTRUCTOR ===
    // ===================

    constructor(
        address _ai,
        uint256 _gameEntryPriceInEth,
        IERC20[] memory _gameTokensAllowedList,
        uint256[] memory _gameTokensEntryPriceList
    ) Ownable(msg.sender) {
        ai = _ai;
        gameEntryPriceInEth = _gameEntryPriceInEth;
        gameTokensAllowedList = _gameTokensAllowedList;
        gameTokensEntryPriceList = _gameTokensEntryPriceList;
    }

    // =========================
    // === PUBLIC FUNCTIONS ====
    // =========================

    // @notice called by AI wallet to initialise a new game
    // @notice creates a new Game struct that players + ratings can then be added to when they join
    function createGame() public onlyAi {
        // increment gameId
        gameId = gameId + 1;

        // create game
        Game storage game = games[gameId];

        // add new game to game mappings indexed by gameId
        games[gameId].gameId = game.gameId;

        // emit event
        emit GameCreated(gameId, block.timestamp, prizePool);
    }

    // @notice generic public joinGame function that calls internal functions depending on whether player pays with Eth or ERC20s
    function joinGame(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        payable
        nonReentrant
    {
        require(games[_gameId].gameEnded == false, "The selected game has ended");

        if (msg.value > 0) {
            _joinGameWithEth(_gameId, _playerRating);
        } else if (_amountOfToken > 0) {
            _joinGameWithTokens(_token, _amountOfToken, _gameId, _playerRating);
        } else (msg.value > 0 && _amountOfToken > 0) {
            Error__JoinWithEitherTokensOrEthNotBoth;
        }
    }

    // @notice allows new players to join a selected game
    // @param user selects a _gameId to play & submits a rating between 1 - 100 for the image
    function _joinGameWithEth(uint256 _gameId, uint256 _playerRating) internal nonReentrant {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value >= gameEntryPriceInEth, "Please send correct amount of Eth to enter");

        // transfer any overpaid Eth to player
        if (msg.value > gameEntryPriceInEth) {
            uint256 refundAmount = msg.value - gameEntryPriceInEth;
            (bool sent,) = payable(msg.sender).call{value: refundAmount}("");
            require(sent, "Failed to refund overpaid Ether");
        }

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating; // Map player address to their rating within the selected game
        games[_gameId].gameBalance += msg.value; // calc value of msg.value - refund amount
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);

        // Interactions - none, Eth accepted into contract

        // emit event
        // *** CHANGE!! emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(0)); <<< address(0) becuase NOT using tokens
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(0));
    }

    // @notice allows new players to join a selected game using ERC20 tokens
    // @param players must pass in an amount of an allow-listed token along with their selected _gameId & image rating
    function _joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        internal
        nonReentrant
    {
        // Checks
        require(_amountOfToken > 0, "Please send a token amount of more than zero to enter");

        // check that token is on the list of allowed tokens & get the entry price denominated in that token
        bool tokenAllowed;
        uint256 tokenEntryPrice;

        // *** DONE!! >>> CHANGE LOGIC!! token allow list is now a mapping > just get the price DIRECTLY using the _token address as the index
        if(gameTokensToEntryPrice[_token] > 0) {
            tokenAllowed = true;
            tokenEntryPrice = gameTokensToEntryPrice[_token];
        }

        // for (uint256 i = 0; i < gameTokensAllowedList.length; i++) {
        //     if (gameTokensAllowedList[i] == _token) {
        //         tokenAllowed = true;
        //         tokenEntryPrice = gameTokensEntryPriceList[i];
        //     }
        // }

        require(tokenAllowed == true, "Token sent is not allowed");

        // check that the user has sent the correct price of entry in tokens
        require(_amountOfToken >= tokenEntryPrice, "Please send correct amount of tokens to enter");

        // transfer any overpaid token amount to player
        // *** CHANGE!! REFUND LOGIC NOT REQUIRED DUE TO EOA APPROVING CORRECT AMOUNT ***
        // if (_amountOfToken > tokenEntryPrice) {
        //     uint256 refundAmountInTokens = _amountOfToken - tokenEntryPrice;
        //     _token.transfer(msg.sender, refundAmountInTokens);
        // }

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        // Map player address to their rating within the selected game
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating;
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);
        // need to update the amount of tokens they've pad (no storage var for this yet)
        // *** ACCOUNTING FOR ERC20S REQUIRED ***

        // Interactions
        // transfer tokens from player to contract (EOA approval required beforehand)
        bool success = _token.transferFrom(msg.sender, address(this), _amountOfToken);
        if (success != true) {
            Error__TokenTransferFailed;
        }

        // emit event
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, _token);
    }

    function endGame(uint256 _aiRating, uint256 _gameId) public onlyAi {
        // set gameEnded to true so nobody else can join
        games[_gameId].gameEnded = true;

        // loop over player ratings and...
        for (uint256 i = 0; i < games[_gameId].numberOfPlayersInGame; i++) {
            // ...compare each player rating to the AI one
            if (games[_gameId].playerAddressesToRatings[games[_gameId].playerKeys[i]] == _aiRating) {
                // store any winners in the winners array
                games[_gameId].winners[i] = games[_gameId].playerKeys[i];
            } else {
                games[_gameId].winners[0] = address(0);
                emit GameEnded(address(0), 0);
            }
        }

        // *** NEED TO BE ABLE TO FINISH THE GAME CORRECTLY WITHOUT A WINNER ***
        require(games[_gameId].winners.length >= 1, "There were no winners of this game");

        // prize pool / winners
        uint256 payoutPerWinner = prizePool / games[_gameId].winners.length;

        // send ether to winners
        for (uint256 j = 0; j < games[_gameId].winners.length; j++) {
            (bool sent,) = payable(games[_gameId].winners[j]).call{value: payoutPerWinner}("");
            require(sent, "Payout to winner failed");
        }

        emit GameEnded(games[_gameId].winners, payoutPerWinner);
    }

    // *** ADD TOKEN PRICE TO TOKENPRICEARRAY TOO! ***
    function addTokenToAllowedList(IERC20 _token) public onlyOwner {
        gameTokensAllowedList.push(_token);
    }

    // *** SET GAME FEE SHOULD BE ONE FUNCTION THAT YOU CAN PASS IN EITHER THE TOKEN + PRICE, OR ETH PRICE ***
    function setGameFee(address _token, uint256 _entryFee) public onlyOwner {

    }

    function getGameFee() public returns (uint256) {

    }

    // =================
    // === MODIFIERS ===
    // =================

    modifier onlyAi() {
        require(msg.sender == ai, "Only the AI can call this function");
        _;
    }
}

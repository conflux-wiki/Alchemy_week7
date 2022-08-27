//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//Console functions to help debug the smart contract just like in Javascript
import "hardhat/console.sol";
//OpenZeppelin's NFT Standard Contracts. We will extend functions from this in our implementation
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {
    address payable owner;
    // import Counters.Counter ofr increment counter variable
    using Counters for Counters.Counter;
    // track for the most recent minted tokenId
    Counters.Counter private _tokenIds;
    //Keep track of the number of sold item on the marketplace
    Counters.Counter private _itemsSold;
    //list price 0.01 ether per nft
    uint256 listPrice = 0.01 ether;

    // structure to store info about listed token
    struct ListedToken{
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    // event, and indexed to help filter the data
    event TokenListedSuccess (
        uint256 indexed tokenId,
        address indexed owner,
        address indexed seller,
        uint256 price,
        bool currentlyListed
    );

    // It is the mapping of all existing tokenId's to the corresponding NFT token
    mapping(uint256=>ListedToken) private idToListedToken;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
    }

    /**
     * @dev The first time a token is created, it is listed here
     * @param tokenURI The URI of token
     * @param price price of the listed token
     * @return newTokenID
     */
    function createToken(string memory tokenURI,uint256 price) public payable returns (uint256) {
        uint256 tokenId = _tokenIds.current();

        _tokenIds.increment();

        //mint deposit nft for seller
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);

        //call createListedToken to list the minted NFT to the contract
        createListedToken(tokenId,price);

        return tokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        // make sure the sender send enouth ETH to pay for listing
        require(msg.value == listPrice, "Does not have enough ETH for listing");
        // security check
        require(msg.value > 0, "Do not send negative or zero");

        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        // transfer from user to contract
        _transfer(msg.sender,address(this),tokenId);

        //emit event
        emit TokenListedSuccess(tokenId,address(this),msg.sender,price,true);
    }

    /**
     * @dev return all the NFTs currently listed to be sold on the market
     */

    function getAllNFTs() public view returns (ListedToken[] memory){
        uint256 minted_count = _tokenIds.current();
        ListedToken[] memory listed_tokens = new ListedToken[](minted_count);// new a memory

        uint256 index = 0;//index listedtoken from idToListedToken

        for(uint i=0;i<minted_count;i++){
            uint current_id = i+1;//id start from 1
            ListedToken memory current_item = idToListedToken[current_id];
            listed_tokens[index++] = current_item;          
        }

        return listed_tokens;

    }

    /**
     * @dev returns all NFTs that current user is owner or seller
     */
    function getMyNFTs() public view returns (ListedToken[] memory){
        address sender = msg.sender;

        uint256 minted_count = _tokenIds.current();
        uint itemcount = 0;// help init the new ListedToken
        uint newlistindex=0;

        for(uint i=0;i<minted_count;i++){
            if(idToListedToken[i+1].owner == sender || idToListedToken[i+1].seller == sender){
                itemcount++;
            }
        }
        // new a list with length itemcount
        ListedToken[] memory sender_token = new ListedToken[](itemcount);
        
        for(uint i=0;i<minted_count;i++){
            if(idToListedToken[i+1].owner == sender || idToListedToken[i+1].seller == sender){
                ListedToken memory current_item = idToListedToken[i+1];
                sender_token[newlistindex] = current_item;
                newlistindex++;
            }
        }
        return sender_token;
    }
    
    /**
     * @dev execute sale operation
     */
    function executeSale(uint256 tokenId) public payable{
        uint listprice = idToListedToken[tokenId].price;//all listed token's list status is true
        address seller = idToListedToken[tokenId].seller;//get seller address
        require(msg.value == listprice,"Plese buy with the list price to fufil the order");
        require(idToListedToken[tokenId].currentlyListed,"Only buy the listed token");

         //update the status of the sold NFT

        idToListedToken[tokenId].seller=payable(msg.sender);
        idToListedToken[tokenId].currentlyListed = false;

        //transfer the NFT to buyer
        _transfer(address(this),msg.sender,tokenId);

        payable(owner).transfer(listPrice);// redemption for the lisrPrice

        payable(seller).transfer(msg.value);

    }

    function upadateListPrice(uint256 _listPrice) public payable onlyOwner {
        // tune the list price grabbed from user
        require(owner == msg.sender,"Only owner can update the listing price");
        listPrice = _listPrice;
    }

    //function get the list price
    function getListPrice() public view returns (uint256){
        return listPrice;
    }

    function getLatestIdToListedToken() public view returns (ListedToken memory){
        uint256 cureentTokenId = _tokenIds.current();
        return idToListedToken[cureentTokenId];
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory){
        return idToListedToken[tokenId];
    }

    function getCurrentTokenId() public view returns (uint256){
        return _tokenIds.current();
    }
    
    modifier onlyOwner {
        require(_msgSender()==owner,"Only owner can call the function");
        _;
    }
}
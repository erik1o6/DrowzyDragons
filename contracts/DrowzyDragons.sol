//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/*
                                                               
@@@@@@@  @@@@@@@   @@@@@@  @@@  @@@  @@@ @@@@@@@@ @@@ @@@      
@@!  @@@ @@!  @@@ @@!  @@@ @@!  @@!  @@!      @@! @@! !@@      
@!@  !@! @!@!!@!  @!@  !@! @!!  !!@  @!@    @!!    !@!@!       
!!:  !!! !!: :!!  !!:  !!!  !:  !!:  !!   !!:       !!:        
:: :  :   :   : :  : :. :    ::.:  :::   :.::.: :   .:         
                                                               
                                                               
@@@@@@@  @@@@@@@   @@@@@@   @@@@@@@   @@@@@@  @@@  @@@  @@@@@@ 
@@!  @@@ @@!  @@@ @@!  @@@ !@@       @@!  @@@ @@!@!@@@ !@@     
@!@  !@! @!@!!@!  @!@!@!@! !@! @!@!@ @!@  !@! @!@@!!@!  !@@!!  
!!:  !!! !!: :!!  !!:  !!! :!!   !!: !!:  !!! !!:  !!!     !:! 
:: :  :   :   : :  :   : :  :: :: :   : :. :  ::    :  ::.: :  

*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "erc721a/contracts/ERC721A.sol";

contract DrowzyDragons is ERC721A, Ownable, Pausable {

    event PermanentURI(string _value, uint indexed _id);

    uint public constant MAX_SUPPLY = 10000;
    uint public constant MAX_PER_MINT = 10;
    uint public constant PRESALE_MAX_MINT = 3;
    uint public constant MAX_DRAGONS_MINTED = 50;
    
    address public constant t1 = 0x2aeb0d72BCDA72EA0d71c00E12a64d9467026556; //CODE2042
    address public constant t2 = 0x4265de963cdd60629d03FEE2cd3285e6d5ff6015; //KEWL
    address public constant t3 = 0xC116bA1542dF6116E2750c1f41bB9e8811A91aF3; //Draco


    uint public constant MAX_RESERVE_SUPPLY = 100;
    string private _contractURI;
    uint private _price = 0.05 ether;

    uint public giftedAmount;
    uint public reservedClaimed;
    uint public numDragonsMinted;

    string public _baseTokenURI;
    string public DRAGONS_PROVENANCE;

    bool public locked;
    bool public publicSaleStarted;
    bool public presaleStarted;
    bool public preRevealTransfer;

    mapping(address => bool) private _presaleEligible;
    mapping(address => uint256) private _totalClaimed; 

    event BaseURIChanged(string baseURI);
    event PresaleMint(address minter, uint256 amountOfDragons);
    event PublicSaleMint(address minter, uint256 amountOfDragons);    

    modifier whenPresaleStarted() {
        require(presaleStarted, "Presale has not started");
        _;
    }

    modifier whenPreRevealTransfer() {
        require(preRevealTransfer, "Can't transfer before Reveal");
        _;
    }

    modifier whenPublicSaleStarted() {
        require(publicSaleStarted, "Public sale has not started");
        _;
    }

    modifier notLocked {
        require(!locked, "Contract metadata methods are locked");
        _;
    }

    // Drowzy Dragons are so Drowzy they dont need a lots of complicated code :)
    constructor(string memory baseURI) ERC721A("Drowzy Dragons", "DROWZY") {
        setBaseURI(baseURI);

        // team gets the first three Dragons
        _safeMint( t1, 1);
        _safeMint( t2, 1);
        _safeMint( t2, 1);
        lockMetadata(3);
    }


    // reserve MAX_RESERVE_SUPPLY for promotional purposes
    function reserveNFTs(address to, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Must mint at least one Dragon");
        require(totalSupply() + quantity <= MAX_RESERVE_SUPPLY, "No more promo NFTs left");
        _safeMint(to, quantity);
        lockMetadata(quantity);
    }

    // Add addresses to presale
    function addToPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Cannot add null address");

            _presaleEligible[addresses[i]] = true;

            _totalClaimed[addresses[i]] > 0 ? _totalClaimed[addresses[i]] : 0;
        }
    }

    // Check to see if you are eligble for the presale
    function checkPresaleEligiblity(address addr) external view returns (bool) {
        return _presaleEligible[addr];
    }

    function amountClaimedBy(address owner) external view returns (uint256) {
        require(owner != address(0), "Cannot add null address");

        return _totalClaimed[owner];
    }   


    // Mint Presale
    function mintPresale(uint256 quantity) external payable whenNotPaused whenPresaleStarted {
        require(quantity > 0, "Must mint at least one Dragon");
        require(_price * quantity == msg.value, "Insufficient funds sent");        
        require(_presaleEligible[msg.sender], "You are not eligible for the presale");
        require(quantity <= PRESALE_MAX_MINT, "Cannot purchase this many tokens during presale");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough NFTs left to mint");
        require(_totalClaimed[msg.sender] + quantity <= PRESALE_MAX_MINT, "Purchase exceeds max allowed");

        _totalClaimed[msg.sender] += quantity;
        _safeMint(msg.sender, quantity);
        lockMetadata(quantity);

        emit PresaleMint(msg.sender, quantity);
    }

    function mint(uint256 quantity) external payable whenNotPaused whenPublicSaleStarted {
        require(quantity > 0, "Quantity cannot be zero");
        require(quantity <= MAX_PER_MINT, "Cannot mint that many at once");
        require(_totalClaimed[msg.sender] + quantity <= MAX_DRAGONS_MINTED, "You can adopt a maximum of 50 Dragons per address");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough NFTs left to mint");
        require(_price * quantity <= msg.value, "Insufficient funds sent");
        

        _totalClaimed[msg.sender] += quantity;
        _safeMint(msg.sender, quantity);
        lockMetadata(quantity);
        emit PublicSaleMint(msg.sender, quantity);
    }

    function lockMetadata(uint256 quantity) internal {
        for (uint256 i = quantity; i > 0; i--) {
            uint256 tid = totalSupply() - i;
            emit PermanentURI(tokenURI(tid), tid);
        }
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable whenPreRevealTransfer override {
    super.transferFrom(from, to, tokenId);
    }

    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadataChange() external onlyOwner {
        locked = true;
    }

    // Just in case Eth does some crazy stuff
    function setPrice(uint256 _newPrice) public onlyOwner() {
        _price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadata() external onlyOwner {
        locked = true;
    }

    function setBaseURI(string memory baseURI) public onlyOwner notLocked{
        _baseTokenURI = baseURI;
    }

    // Must be set before sale starts
    function setProvenanceHash(string calldata hash) external onlyOwner notLocked {
        DRAGONS_PROVENANCE = hash;
    }

    function setContractURI(string calldata URI) external onlyOwner notLocked {
        _contractURI = URI;
    }

    function getContractURI() public view returns (string memory) {
        return _contractURI;
    }

    // Toggle presale
   function togglePresaleStarted() external onlyOwner {
        presaleStarted = !presaleStarted;
    }

   function togglePreRevealTransfer() external onlyOwner {
        preRevealTransfer = !preRevealTransfer;
    }

    // Toggle Sale
    function togglePublicSaleStarted() external onlyOwner {
        publicSaleStarted = !publicSaleStarted;
    }

    function withdrawAll() public onlyOwner {
        uint256 _each = address(this).balance / 3;
        require(payable(t1).send(_each));
        require(payable(t2).send(_each));
        require(payable(t3).send(_each));        
    }
    //hello world
}

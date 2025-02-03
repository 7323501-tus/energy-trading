// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
contract Trading20 {
    address public owner;
    uint256 public RecalculateCount;
    uint256 ci = 0;                 // consumerListCount                   
    uint256 pi = 0;                 // prosumerListCount                                           
    uint256 public tradeCount = 0;  // dealCount
    uint256 public totalConsumerSum = 0;
    uint256 public totalProsumerSum = 0;

    // Array to count the number of times each trade volume (1-25 kWh) occurs
    uint256[26] public tradeVolumeCount;  // 0 index is unused, so 1-25 are valid indexes


    event DicisionContractPrice(uint256 ContractPrice);
    event TradeExecuted(uint consumerNumber, uint prosumerNumber, uint256 tradeVolume);
    event CountReport(uint tradeVolume, uint count);

    modifier onlyOwner() {
        require(owner == msg.sender, "only owner!");
        _;
    }

    address consumeraddress;
    address prosumeraddress;
    struct Consumer {
        address consumer;           // consumer Hash値
        uint256 number;             // consumer id
        uint256 kwh;                // consumer kwh
        uint256 value;              // consumer value
        uint256 distance;           // consumer distance
        uint256 allow;              // consumer allowable rate
        uint256 allowableError;     // consumer allowable limit of error
        uint256 sum;                // consumer sum 
    }

    struct Prosumer {
        address prosumer;           // prosumer Hash値
        uint256 number;             // prosumer id                
        uint256 kwh;                // prosumer kwh              
        uint256 kwh_r;              // prosumer kwh considering error rate
        uint256 value;              // prosumer value
        uint256 distance;           // prosumer distance
        uint256 allow;              // prosumer error rate
        uint256 predictionError;    // prosumer prediction error
        uint256 sum;                // prosumer sum
    }

    Consumer[] public consumerList;
    Prosumer[] public prosumerList;

    mapping(address => uint) public confirmProsumer;
    constructor() {
        RecalculateCount = 0;
        owner = msg.sender;
        consumeraddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        prosumeraddress = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    }

    //Create Consumer by Gaussian distribution
    function C10ConsumerData(uint steps) public {
        Consumer[] memory consumerresult = new Consumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];
                uint distance = 1 + blockHash % 5;
                uint allow = 100 - blockHash % 11;
                uint allowableError = (allow * kwh) / 100;

                Consumer memory newconsumer = Consumer(
                    consumeraddress,                                // consumer Hash値
                    number,                                         // consumer id
                    kwh,                                            // consumer kwh
                    value,                                          // consumer value
                    distance,                                       // consumer distance
                    allow,                                          // consumer allowable rate
                    allowableError,                                 // consumer allowable limit of error
                    0                                               // consumer sum 
                );                                             
                consumerresult[sum + idx] = newconsumer;
                number++; 
            }
            sum += endpoint[loop];
        }
        for (uint i = 0; i < consumerresult.length; i++) {
            consumerList.push(consumerresult[i]);
        }
    }
    
    // Create Prosumer by Gaussian distribution
    function C10ProsumerData(uint steps) public {
        Prosumer[] memory prosumerresult = new Prosumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpoint.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];
                uint distance = 1 + blockHash % 5;                                             
                uint allow = 100 - blockHash % 31;                                              
                uint kwh_r = (kwh * allow)/100;                         
                uint predictionError = absDiff(kwh, kwh_r);                                     

                Prosumer memory newprosumer = Prosumer(
                    prosumeraddress,                                // prosumer Hash値  
                    number,                                         // prosumer id
                    kwh,                                            // prosumer kwh
                    kwh_r,                                          // prosumer kwh considering error rate
                    value,                                          // prosumer value
                    distance,                                       // prosumer distance
                    allow,                                          // prosumer error rate
                    predictionError,                                // prosumer prediction error
                    kwh                                             // prosumer sum
                );                                           
                prosumerresult[sum + idx] = newprosumer;
                number++; 
            }
            sum += endpoint[loop];
        }
        for (uint i = 0; i < prosumerresult.length; i++) {
            prosumerList.push(prosumerresult[i]);
        }
    }

    ///////////////////////////////////////////////////
    function Agreement() public onlyOwner returns (uint256, uint256, uint256, uint256) {
        uint256 ContractPrice = 0;

        while (ci < consumerList.length && pi < prosumerList.length) {
            if (consumerList[ci].value >= prosumerList[pi].value) {
                uint256 remainingConsumerKwh = consumerList[ci].kwh - consumerList[ci].sum;
                uint256 prosumerKwhSum = prosumerList[pi].sum;

                uint256 tradeVolume = (remainingConsumerKwh < prosumerKwhSum) ? remainingConsumerKwh : prosumerKwhSum;

                // Track tradeVolume count if within range (1-25)
                if (tradeVolume > 0 && tradeVolume <= 25) {
                    tradeVolumeCount[tradeVolume]++;
                }
            
                if (remainingConsumerKwh < prosumerKwhSum) {
                    prosumerList[pi].sum -= remainingConsumerKwh;
                    consumerList[ci].sum = consumerList[ci].kwh;
                    tradeCount += 1;
                    ci += 1;

                    emit TradeExecuted(consumerList[ci].number, prosumerList[pi].number, remainingConsumerKwh);

                } else if (remainingConsumerKwh == prosumerKwhSum) {
                    consumerList[ci].sum = consumerList[ci].kwh;
                    prosumerList[pi].sum = 0;
                    tradeCount += 1;
                    ci += 1;
                    pi += 1;

                    emit TradeExecuted(consumerList[ci].number, prosumerList[pi].number, prosumerKwhSum);


                } else {
                    consumerList[ci].sum += prosumerKwhSum;
                    prosumerList[pi].sum = 0;
                    tradeCount += 1;
                    pi += 1;

                    emit TradeExecuted(consumerList[ci].number, prosumerList[pi].number, prosumerKwhSum);
                }
            } 
            else {
                ContractPrice = prosumerList[pi].value;
                break;
            }
        }

        for (uint256 i = 0; i < consumerList.length; i++) {
            totalConsumerSum += consumerList[i].sum;
        }
        for (uint i = 0; i < prosumerList.length; i++) {
            totalProsumerSum += prosumerList[i].sum;
        }

        emit DicisionContractPrice(ContractPrice);
        outputCounts();  // Output trade volume counts
        return (ContractPrice, totalConsumerSum, totalProsumerSum, tradeCount);
    }

    ///////////////////////////////////////////////////
    // Output the count of trades by trade volume (1-25 kWh)
    function outputCounts() internal {
        for (uint i = 1; i <= 25; i++) {
            emit CountReport(i, tradeVolumeCount[i]);
        }
    }

    function absDiff(uint a, uint b) internal pure returns (uint) {
        return a > b ? a - b : b - a;
    }

    // Consumer Counting-sort by value
    function countingSortConsumers() public {
        uint256 maxvalue = 19;
        uint256[] memory count = new uint256[](maxvalue + 1);
        Consumer[] memory sorted = new Consumer[](consumerList.length);
        for (uint i = 0; i < consumerList.length; i++) {
            count[consumerList[i].value]++;
        }
        for (uint i = maxvalue; i > 0; i--) {
            count[i - 1] += count[i];
        }
        for (int i = int(consumerList.length) - 1; i >= 0; i--) {
            Consumer storage consumer = consumerList[uint(i)];
            sorted[count[consumer.value] - 1] = consumer;
            count[consumer.value]--;
        }
        for (uint i = 0; i < consumerList.length; i++) {
            consumerList[i] = sorted[i];
        }
    }
    //////////////////////////////////////////////////
    // Prosumer Counting-sort by value
    function countingSortProsumers() public {
        uint256 maxvalue = 19;
        uint256[] memory count = new uint256[](maxvalue + 1);
        Prosumer[] memory sorted = new Prosumer[](prosumerList.length);

        for (uint i = 0; i < prosumerList.length; i++) {
            count[prosumerList[i].value]++;
        }
        for (uint i = 1; i <= maxvalue; i++) {
            count[i] += count[i - 1];
        }
        for (int i = int(prosumerList.length) - 1; i >= 0; i--) {
            Prosumer storage prosumer = prosumerList[uint(i)];
            sorted[count[prosumer.value] - 1] = prosumer;
            count[prosumer.value]--;
        }
        for (uint i = 0; i < prosumerList.length; i++) {
            prosumerList[i] = sorted[i];
        }
    }
}
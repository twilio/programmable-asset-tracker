#require "Promise.lib.nut:4.0.0"
#require "utilities.lib.nut:3.0.1"

@include once "../src/shared/Logger/Logger.shared.nut"
@include once "Esp32Loader.device.nut"

// If firmware loaded successfully:
// 2022-06-24T20:18:25.410 +00:00 	[Device] 	Simple test ESP loader
// 2022-06-24T20:18:28.389 +00:00 	[Device] 	[INFO][ESP32Loader] Prepare success
// 2022-06-24T20:18:28.413 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 0
// 2022-06-24T20:18:28.651 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 1
// 2022-06-24T20:18:28.925 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 2
// 2022-06-24T20:18:29.246 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 3
// 2022-06-24T20:18:29.606 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 4
// 2022-06-24T20:18:29.906 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 5
// 2022-06-24T20:18:30.204 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 6
// 2022-06-24T20:18:30.526 +00:00 	[Device] 	[INFO][ESP32Loader] Send packet. Sequnce number: 7
// 2022-06-24T20:18:30.868 +00:00 	[Device] 	[INFO][ESP32Loader] Verification MD5.
// 2022-06-24T20:18:31.068 +00:00 	[Device] 	Load firmware success
// 2022-06-24T20:18:32.243 +00:00 	[Device] 	ets Jun  8 2016 00:22:57
// 2022-06-24T20:18:32.243 +00:00 	[Device] 	rst:0x1 (POWERON_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
// 2022-06-24T20:18:32.265 +00:00 	[Device] 	configsip: 0, SPIWP:0xee
// 2022-06-24T20:18:32.307 +00:00 	[Device] 	clk_drv:0x00,q_drv:0x00,d_drv:0x00,cs0_drv:0x00,hd_drv:0x00,wp_drv:0x00
// 2022-06-24T20:18:32.307 +00:00 	[Device] 	mode:DIO, clock div:2
// 2022-06-24T20:18:32.328 +00:00 	[Device] 	load:0x3fff0008,len:1564
// 2022-06-24T20:18:32.341 +00:00 	[Device] 	ho 0 tail 12 room 4
// 2022-06-24T20:18:32.371 +00:00 	[Device] 	load:0x40078000,len:3976
// 2022-06-24T20:18:32.389 +00:00 	[Device] 	ho 0 tail 12 room 4
// 2022-06-24T20:18:32.389 +00:00 	[Device] 	load:0x40080400,len:2492
// 2022-06-24T20:18:32.424 +00:00 	[Device] 	entry 0x40080574
// 2022-06-24T20:18:32.424 +00:00 	[Device] 	[0;32mI (30) boot: TEST APPLICATION

// Simple application address in the ESP flash
APP_SIMPLE_TEST_ESP_FLASH_ADDR <- 0x00;
// MD5 sum of simple application
APP_SIMPLE_TEST_MD5 <- "4f13d643633c42515beb78e33b7cf297";
// Simple application periodically print to UART debug info and message "TEST APPLICATION"
APP_SIMPLE_TEST <- "e903022000e03c40ee0000000500030000000000000000010860cd3f74020000417373657274206661696c656420696e2025732c2025733a256420282573290d0a00000061626f72742829207761732063616c6c6564206174205043203078253038780d0a000000626f6f746c6f616465725f696e697400265f6273735f7374617274203c3d20265f6273735f656e64000000002f2f686f6d652f77652f446576656c6f702f65737033322f6573702d61742d72697363762f6573702d61742f6573702d6964662f636f6d706f6e656e74732f626f6f746c6f616465725f737570706f72742f7372632f657370333263332f626f6f746c6f616465725f657370333263332e630000265f646174615f7374617274203c3d20265f646174615f656e6400001b5b303b33326d4920282575292025733a2054455354204150504c49434154494f4e1b5b306d0a00626f6f74000000001b5b303b33316d4520282575292025733a206661696c656420746f206c6f616420626f6f746c6f6164657220696d61676520686561646572211b5b306d0a00007274635f636c6b5f696e6974000000001b5b303b33316d4520282575292025733a20696e76616c696420435055206672657175656e63792076616c75651b5b306d0a0000905f010000800000b38100001b5b303b33316d4520282575292025733a20756e737570706f72746564206672657175656e637920636f6e66696775726174696f6e1b5b306d0a00007274635f636c6b001b5b303b33316d4520282575292025733a20696e76616c6964206672657175656e63791b5b306d0a000000001b5b303b33336d5720282575292025733a20696e76616c6964205254435f5854414c5f465245515f5245472076616c75653a203078253038781b5b306d0a000000e03c4044050000411106c6292019c1ef20a00301a0411106c6ef202002894763e8a70285471147914601468145130510069740c3ffe7806093b14701478d46054681451305a0069740c3ffe7800092ef10d07e854763fda7008947630ff5060545ef2080050545ef20a007054501a80545ef2080040145ef20a0060145ef20e00837371d8fb78700601307a71223a8e70a03a7c70ab7060080558f23a6e70a23a8070a2d2a3767cd3fb767cd3f130707009387870063f7e702b766cd3f3766cd3f93860606130606059305e0133765cd3f1305a50def10d0790545ef10f07d054559bf3767cd3fb767cd3f130787009387870063fde700b766cd3f3766cd3f9386060f130606059305f013c9b7c9289720c3ffe780c0419720c3ffe780803c9720c3ffe7804044b7470c60d843799bd8c3d843759bd8c329206922d920852201a00111014506ce9720c3ffe78040f4ef20b01bb7b7c4049387f73f63e8a7062247b7071c00f98f156713078702d98f3ec499679387f74f2316f100ef20e0530d899317350122453707e8ff7d17798d5d8d2ac4ef20405705899317250122453707fcff7d17b245798d5d8d2ac48924ef20204119e1ef20a040b7870060f24023a007047d57f8c70561828001459720c3ffe78020e5b147e314f5f8d1bf21aa3765cd3fb767cd3f13060500938787003386c7408145130505001723c3ff670023160111b7870060938707000a8506ce3ec222cc02c0ef20e02081450a85ef2000260a85ef2080218146014681450a85ef103070ef2000492a840a85ef20801e096513058532b335a4021306803e81463305a4029720c3ffe78000662a86914681450a85ef20c00a0a85ef20401e0a85ef20c01c85473ec4b7f701609387070028003ec6ef20001a28008145ef20201f2800ef20a01af240624405618280411106c6ef105057b2403766cd3faa853765cd3f130646131305c51041011723c3ff6700c3d8411106c69720c3ffe78080d801459720c3ffe780a0dbef201003b2407166b765620213060620938505a0014541016f107051b70700087390073b93068008f3a7063ab707000a7390173ba567138707f07327073a3707000f7310273b370788007326073a3706f20f7310363b370600897326063a3786f30f7310463b1306b0087326163a3786fc0f7310563b138607907326163a378601107310663b37068d007326163a37f60d107310763b370600887326163a37860f107310863b1306f0087326263a3706a0107310963b138607d07326263a370600147310a63b7326273a37160014130606807310b63b3706008f7326263a370600187310c63bf3a6363ab70604187390d63b938707b0f3a7373ab7070040fd177390e73b7327373a7390f73bb7070090f3a7373a828039712ec637870060832607088347c1003746c0ff7d16f18eba0706de22dc26da2ac4d58f2320f708345b8347d10021811374f53f370602fe22457d16f18ec607d58f55813cdb1375f50fef20c06f22457581ef206072b7e70060f843b7060400938606f0558ff8c3f843b7c6fdfffd16758f83448100f8c301459720c3ffe78020c22685ef20805637450f00130505243385a402ef20c0560808ef2080490c102285f244ef20204315e1ef10d037aa853766cd3f3765cd3f1306c6171305c5189720c3ffe78080b9ef10b03d0810ef2080597325207eb335a402268681463305a4029720c3ffe780203e7310257ea247131584003704fcff1304f40f7d8c498cb704180022c4e18cb70708006395f4000545ef20200a9317d40063da0700b705f0ffa69593b515000545ef20800c224549810589ef20001c22454d810d89ef202013f2506254d254216182800000000000000000000000000000000000003d40880b00009205b3d5c5021703c3ff67002308411106c622c47324207e9700c3ffe780c0569307803e3305f502b2403355a402224441018280b797006003a5078549811d898280411106c629281305803e9700c3ffe7804000b78700603707008098c301a001451703c3ff6700e301b2872a863765cd3f4111368713058500ae86be8506c69700c3ffe78000fc01a03765cd3f41119385d0ff1305c50206c69700c3ffe78060fab7e70c6083a78709898b91c3029001a0b787006003a7c7106d9b23a6e71003a7c70a19c5b7060200558f23a6e70a82808176fd16758fd5bfb787006003a7c710759b23a6e71003a7870d19c5b7060010558f23ace70c8280b70600f0fd16758fcdbfb787006003a7c710799b23a6e710d85b11c5b7061000558fd8db8280b706f0fffd16758fd5bf797122d426d22e84b2848145214636c606d69700c3ffe78080210547aa87b246631be40e37f7016013070700d8c380c33747d850dc43130717aa858a75e823a4e70a03a70709370600801346f6ff718f23a8e70803a70709370600907d16718f23a8e70803a70709370600f27d16718f23a8e70803a70709370640fe7d16718f23a8e70803a707093706c8ff7d16718f23a8e70803a707098e063acc6247137707f03acc624723a8e70803a707091377f7ef23a8e708f84713678700f8c7b8435d9bd98eb4c303a707098566938606801367074023a8e70803a70709558f23a8e70803a70709b70607001367072023a8e70803a70709558f23a8e70803a70709b966558f23a8e70823a4070ab250225492544561828009476317e400370702601307070021b73787006013070700fdbdf8d3b847370600801346f6ff718fb8c7b847370600a07d16718fb8c7b847b7054000370600e84d8fb8c7b8477d168606718fb8c7b847370600fa7d164d8fb8c7b847c204718fb8c7b847370680fe7d164d8fb8c7b847718fb8c7b8474d8fb8c7f85f13672700f8dfb85b759bd98eb4dbb847b7061c00558fb8c7b847b78603004d8fb8c7b847558fb8c7b8474d8fb8c7f8473ace724642064182458e32ce7247f8c7b847d98dacc723a2070605bf18415c4141ef05479d8a6382e50491c90947638be5040d476385e506411106c68d3303a70709b7050090fd156d8ff206d98e23a8d708379700600327478341830d8b05073357e60023aae708828003a70709b70500f2fd15e6066d8fd98e23a8d70823acc708828003a70709b70540fefd15da066d8fd98e23a8d70823aec708828003a70709b705c8fffd15ce066d8fd98e23a8d70823a0c70a82800547638ae50289cd09476381e5040d476389e504b847b7064000558fb8c78280b847b70500a08d8afd15f6066d8fd98eb4c7b0cbc5b7b847b70500e88d8afd15ee066d8fd98eb4c7f0cbe9b7b847b70500fa8d8afd15e6066d8fd98eb4c7b0cf55bfb847b70580fe8d8afd15de066d8fd98eb4c7f0cf79bf1441b747d8505841938717aa81e62324f70a82807cd3828018415c4101e723a4070a828023a20706828018415c4111ef83a6470a37060080d18e23a2d70a03a70709518f23a8e70882800547b8d3b847b7060080558fb8c7828018415c41858919eb03a70709fd76fd16b205758fd98d23a8b7088280b847f176fd16758fba05d98dacc7b847b7064000558fb8c78280378700601c4393e707541cc3b767cd3f23a007008280930700056308f5029307000a85466304f502411106c61d3eaa853766cd3f3765cd3f13068620130505219700c3ffe78040b5593e8146b7070c609847719b558f98c7b84ffd769386f63f137707c0b8cfb84f758f13670740b8cfb7574b4c378700609387b7c4232ef70a1703c3ff6700c305b7870060b4531317150137060e00718f3706f2ff7d16f18e558fb8d3b4531357650049767d161d8bf18e3607558fb8d3b4531357950079761d8b1306f63ff18e2a07558fb8d3b8530d81137505201377f7df598da8d3b853c166558fb8d3828005651305356c69bf11c1ddbfb7870060b853c176fd1613670708b8d3b853758fb8d38280f1bfb7870060bc53014513d77700058b11c7c18393c7170013f5170013451500828031c5378700603c5b01112ec606ce93f7f7fb3cdb5c4ff1769386f603f58f93e707145ccf130520039700c3ffe780e0a437870060b2453c5b99c593f7f7f7f2403cdb0561828093e70708d5bf378700603c5bf1769386f60393e707043cdb5c4ff58f93e707505ccf378700603c5b89c593f7f7f73cdb828093e70708e5bf378700603c5bb7060040fd16f58f9316e501d58f3cdb3c5b85461307001093f7f7ef6303d5000147d98f378700603cdb3c5b370700fc7d178946f98f370700046303d5000147d98f378700603cdb1305c0121703c3ff6700639ab7870060a85b79818280b7870060bc5b0d470145f9836389e7003767cd3f8a071307071cba9788438280b7860060bc5a370700207605798d370700e07d17f98f5d8da8da0d451703c3ff67008395b7870060a85b758105898280b7e70060b843011156c206ce22cc26ca4ac84ec652c46d9bb8c3b843ae8a13678700b8c39307001e37070c606390f5101c4793e747001cc7930700026313f50e81499144694905449306b00611468145130560069710c3ffe780c01f228a93964400c18e09468145130560069710c3ffe780401eca860d468145130560069710c3ffe780201dd2870147894615468145130560069710c3ffe780001cd2871147994615468145130560069710c3ffe780a01a93e6090919468145130560069710c3ffe780201989470147854625468145130560069710c3ffe780001889471147954619468145130560069710c3ffe780a016854719479d4619468145130560069710c3ffe7804015f2406244b767cd3f23a05701d2444249b249224a924a056182808d4995442149014439bf1c47ed9b1cc7930700026312f502194905449306900611468145130560069710c3ffe78060108d499544014a19b711490144c5b7b787006083a6870b13950601418193d706016317f5009387f6ff7557637af702011106ce36c6eff0cff7b246aa853766cd3f3765cd3f130686201305c52397f0c2ffe7806079f24013058002056182808280011122cc2ec606ce2a845537b2456364850233578502aa8793561700aa96b3d6e60201456313d402814694c1dcc198c5c0c5054519a893070005630cf4009307000a01450d476307f400f240624405618280194785469307001ec1bf4111b7070c6022c4a04f4ac006c6298026c20d8805472a89630ce4040dc48947630ff406eff00fedaa853766cd3f3765cd3f130686201305c51c97f0c2ffe780c06eeff0eff2a44f293793f4f43f8504b357950223208900b2402244232499002322a9002326f900924402494101828098479c470d8b8983858b95e71305001419e793070005914413050014e1b78547e31af7f805449307000a8d4465bfa1478544214545bf1305001e75f33e849944930700051305001e71bf93170501c18342055d8db787006023aca70a8280318193170501c18342055d8db787006023aea70a8280011122cc06ce2a842ec69700c3ffe78000b8b7070c60b84fb24537450f00137707c0b8cfb84f13050524fd153305a402137707c093f5f53fd98daccfb84ffd7662449386f63ff240758fb8cf056171bf011126cab7040c6022cca04c1c414ac8298006ce4ec62a890d8891ef0c454845413f85476311f4086244f240d2444249b24905612db4854963973703630cf400378700601c4393f7f7ab1cc3c93b83254900b53162440325c900f240d2444249b249056101bc0947639fe70221459700c3ffe780c0acbc4c7d771307f73f93f707c0bcccbc4cf98f056713070780d98fbcccb7171b08378700609387b781232ef70ae30334f9f2406244d2444249b24905618280b787006083a7c70b37f5ff0fb207e98f37a5070013050512aa9737450f001305052433f5a7023385a7408280b7870060f85bb706c0fffd16758ff8dbf85bb706807f5e05758db7068080fd16758f598de8dbf85bb7064000558ff8db8280b7870060b85b9d6632055d9bb8dbb85b758de576fd16758f598da8dbb85b13678700b8db82800000000000000000000000000000000000f06c6cfcc9e63674ce409d38f8bf1d8ac542d1b30d0c0f4e41e9eb48313d5059e8";

// start delay
const APP_SWITCH_START_DELAY = 1;
// new RX FIFO size
const APP_RX_FIFO_SIZE = 256;
// UART settings
const APP_DEFAULT_BAUDRATE = 115200;
const APP_DEFAULT_BIT_IN_CHAR = 8;
const APP_DAFAULT_STOP_BITS = 1;

// The available range for erasing
const APP_IMP_FLASH_START_ADDR = 0x000000;
// Flash sector size
const APP_IMP_FLASH_SECTOR_SIZE = 0x1000;

class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

    function _get(key) {
        if (!(key in _switchPin)) {
            throw null;
        }

        // We want to clock the flip-flop after every change on the pin. This will trigger clocking even when the pin is being read.
        // But this shouldn't affect anything. Moreover, it's assumed that DIGITAL_OUT pins are read rarely.
        // To "attach" clocking to every pin's function, we return a wrapper-function that calls the requested original pin's
        // function and then clocks the flip-flop. This will make it transparent for the other components/modules.
        // All members of hardware.pin objects are functions. Hence we can always return a function here
        return function(...) {
            // Let's call the requested function with the arguments passed
            vargv.insert(0, _switchPin);
            // Also, we save the value returned by the original pin's function
            local res = _switchPin[key].acall(vargv);

            // Then we clock the flip-flop assuming that the default pin value is LOW (externally pulled-down)
            _clkPin.configure(DIGITAL_OUT, 1);
            _clkPin.disable();

            // Return the value returned by the original pin's function
            return res;
        };
    }
}

// Imp UART connected to the ESP32C3
APP_ESP_UART <- hardware.uartPQRS;
// ESP32 power on/off pin
APP_SWITCH_PIN <- FlipFlop(hardware.pinYD, hardware.pinS);
// Strap pin 1 (ESP32C3 GP9 BOOT)
APP_STRAP_PIN1 <- hardware.pinH;
// Strap pin 2 (ESP32C3 EN CHIP_EN)
APP_STRAP_PIN2 <- hardware.pinE;
// Strap pin 3 (ESP32C3 GP8 PRINTF_EN)
APP_STRAP_PIN3 <- hardware.pinJ;
// Flash parameters
APP_ESP_FLASH_PARAM <- {"id"         : 0x00,
                        "totSize"    : ESP32_LOADER_FLASH_SIZE.SZ4MB,
                        "blockSize"  : 65536,
                        "sectSize"   : 4096,
                        "pageSize"   : 256,
                        "statusMask" : 65535};

server.log("Simple test ESP loader");
// erase imp flash region
local simple_test_len = APP_SIMPLE_TEST.len() / 2;
local sectorCount = (simple_test_len + APP_IMP_FLASH_SECTOR_SIZE - 1) / APP_IMP_FLASH_SECTOR_SIZE;
local spiFlash = hardware.spiflash;
spiFlash.enable();
for (local addr = APP_IMP_FLASH_START_ADDR;
     addr < (APP_IMP_FLASH_START_ADDR +
             sectorCount*APP_IMP_FLASH_SECTOR_SIZE);
     addr += APP_IMP_FLASH_SECTOR_SIZE) {
    spiFlash.erasesector(addr);
}
// write simple test application to imp flash
spiFlash.write(APP_IMP_FLASH_START_ADDR,
               utilities.hexStringToBlob(APP_SIMPLE_TEST));
spiFlash.disable();

// data from ESP
res <- "";
// get data from UART
function loop() {
    local data = APP_ESP_UART.read();
    // read until FIFO not empty and accumulate to res string
    while (data != -1) {
        res += data.tochar();
        data = APP_ESP_UART.read();
    }
    if (res.len()) {
        // split to strings
        local resArr = split(res, "\r\n");
        foreach (el in resArr) {
            server.log(el);
        }
        res = "";
    }
}
// init ESP32Loader class
espLoader <- ESP32Loader({
                            "strappingPin1" : APP_STRAP_PIN1,
                            "strappingPin2" : APP_STRAP_PIN2,
                            "strappingPin3" : APP_STRAP_PIN3
                         },
                         APP_ESP_UART,
                         APP_ESP_FLASH_PARAM,
                         APP_SWITCH_PIN);
espLoader.start().then(function(res) {
    // load firmware to ESP flash
    espLoader.load(APP_IMP_FLASH_START_ADDR,
                   APP_SIMPLE_TEST_ESP_FLASH_ADDR,
                   simple_test_len,
                   APP_SIMPLE_TEST_MD5)
                   .finally(function(resOrErr) {
                        server.log(resOrErr);
                        espLoader.finish().then(function(res) {
                            APP_SWITCH_PIN.configure(DIGITAL_OUT, 0);
                            imp.sleep(APP_SWITCH_START_DELAY);
                            APP_SWITCH_PIN.configure(DIGITAL_OUT, 1);
                            APP_ESP_UART.disable();
                            APP_ESP_UART.setrxfifosize(APP_RX_FIFO_SIZE);
                            APP_ESP_UART.configure(APP_DEFAULT_BAUDRATE,
                                                   APP_DEFAULT_BIT_IN_CHAR,
                                                   PARITY_NONE,
                                                   APP_DAFAULT_STOP_BITS,
                                                   NO_CTSRTS,
                                                   loop);
                            }.bindenv(this));
                    }.bindenv(this));
}.bindenv(this));
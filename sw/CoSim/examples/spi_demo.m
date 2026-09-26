% Demo pattern for a PulseView screenshot (CoSim): an SPI master FSM reading
% an ADXL345 accelerometer. The Waveform Generator (port 4243) plays it, the
% Logic Analyzer (port 4242) records it.
%
% Channels (Logic Analyzer probe = Waveform Generator output):
%   D2..D0   FSM state   0 IDLE, 1 SELECT, 2 CMD, 3 DATA, 4 DESELECT
%   D3       busy        1 while not IDLE
%   D4       CS#         SPI chip select, active low
%   D5       SCLK        SPI clock, mode 3 (CPOL = 1, CPHA = 1)
%   D6       MOSI
%   D7       MISO
%   D15..D8  byte counter within the SPI transfer (at most 7, D10..D8 suffice)
%
% PulseView: SPI decoder with CLK = D5, MOSI = D6, MISO = D7, CS# = D4,
% CPOL = 1, CPHA = 1, MSB first, 8 bit words; stack the ADXL345 decoder on it.
% Numbers and State decoder on D2..D0, interpretation enum, mapping file
% spi_demo_states.json. See sw/CoSim/README.md.

IDLE = 0; SELECT = 1; CMD = 2; DATA = 3; DESELECT = 4;
CS = 16; SCLK = 32; MOSI = 64; MISO = 128;   % bit weights of the SPI lines
BUSY = 8;

n_samples = 512;          % sample memory of the CoSim Waveform Generator
half = 2;                 % samples per half SCLK period

% two transfers: command byte (MOSI), then the answer bytes (MISO)
% 1) read DEVID (register 0x00): 0x80 = read -> answer 0xE5
% 2) read DATAX0..DATAZ1 (0x32..0x37): 0xF2 = read, multi byte -> 6 bytes,
%    X = 2, Y = -3, Z = 256 (about 0 g, 0 g, 1 g at 3.9 mg/LSB)
xyz = [2 -3 256];
xyz_bytes = [];
for v = mod(xyz, 65536)                     % two's complement, LSB first
  xyz_bytes = [xyz_bytes, bitand(v, 255), bitshift(v, -8)];
end
transfers = {[0x80], [0xE5]; [0xF2], xyz_bytes};

% one SPI byte, MSB first: SCLK falls, data changes, SCLK rises (sampled)
function s = spi_byte(value, line, extra, half, SCLK)
  s = [];
  for b = 7:-1:0
    % double(): hex literals like 0x80 are uint8 in Octave, sums would saturate at 255
    d = double(bitget(value, b + 1)) * line;
    s = [s, repmat(extra + d, 1, half), repmat(extra + d + SCLK, 1, half)];
  end
end

wave = [];
for t = 1:rows(transfers)
  cmd = transfers{t, 1};
  answer = transfers{t, 2};
  count = 0;
  % CS# high, SCLK high (idle of mode 3) -> SELECT: CS# low
  wave = [wave, repmat(SELECT + BUSY + SCLK, 1, 4)];
  for c = cmd
    count = count + 1;
    wave = [wave, spi_byte(c, MOSI, CMD + BUSY + count * 256, half, SCLK)];
  end
  for a = answer
    count = count + 1;
    wave = [wave, spi_byte(a, MISO, DATA + BUSY + count * 256, half, SCLK)];
  end
  wave = [wave, repmat(DESELECT + BUSY + SCLK + count * 256, 1, 4)];
  % CS# high again; IDLE until the next transfer, filled up below
  wave = [wave, repmat(IDLE + CS + SCLK, 1, 40)];
end
% fill up the sample memory with IDLE, so the repetition is seamless
wave = [wave, repmat(IDLE + CS + SCLK, 1, n_samples - numel(wave))];

WaveformGenerator;
wfg = WaveformGenerator.IpdbgWaveformGenerator();
wfg.open("127.0.0.1", "4243");
wfg.write(wave);
wfg.start();
wfg.close();

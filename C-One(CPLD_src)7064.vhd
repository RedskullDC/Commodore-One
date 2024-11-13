library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity io is
port(
wr : in std_logic;
a : in std_logic_vector(2 downto 0);
d : inout std_logic_vector(7 downto 0);

csel : in std_logic_vector(3 downto 0);

shift_out : out std_logic;

cpureset : buffer std_logic;

irq : out std_logic;

nclr : in std_logic;
pci_clk : in std_logic;
clk1mhz : in std_logic;

joyb : in std_logic_vector(6 downto 0);
joya : in std_logic_vector(6 downto 0);

lptd : inout std_logic_vector(7 downto 0);
lptstrobe : inout std_logic;
lpt_bsy : in std_logic;

seratn : inout std_logic;
serclk : inout std_logic;
serrq : inout std_logic;
serdata : inout std_logic;

pirq : in std_logic;
pgnt0 : out std_logic;
pgnt1 : out std_logic;
serr : in std_logic;
perr : in std_logic;

clkirq : in std_logic;
ide1irq : in std_logic;
ide2irq : in std_logic;

buffer_en : out std_logic;

nconfig : out std_logic;
enable : in std_logic --chipenable
);

end io;

architecture Behavior of io is
signal clear_irq : std_logic;
signal err_irq_stored : std_logic;

signal ide_irq : std_logic;
signal irq_enable : std_logic;

signal pa : std_logic_vector(5 downto 2);

signal lpdata : std_logic_vector(7 downto 0);
signal lpdir : std_logic_vector(7 downto 0);

signal shift : std_logic;
signal shift_count : std_logic_vector(3 downto 0);
begin

--0000 roml
--0001 io2
--0010 clk1
--0011 sid1
--0100 romh
--0101 io1
--0110 clk2
--0111 sid2

--1000 buffer_en enable status register buffer
--1001 lpdata latch data bus to printer data output register
--1010 lpdir latch data bus to printer direction register
--1011 --serial port registers
--1100 --PCI GNT RESET
--1101 --PCI0 GRNT SET
--1110 --PCI1 GRNT SET
--1111 nop

lptd(0) <= '0' when lpdata(0) = '0' and lpdir(0) = '1' else 'Z';
lptd(1) <= '0' when lpdata(1) = '0' and lpdir(1) = '1' else 'Z';
lptd(2) <= '0' when lpdata(2) = '0' and lpdir(2) = '1' else 'Z';
lptd(3) <= '0' when lpdata(3) = '0' and lpdir(3) = '1' else 'Z';
lptd(4) <= '0' when lpdata(4) = '0' and lpdir(4) = '1' else 'Z';
lptd(5) <= '0' when lpdata(5) = '0' and lpdir(5) = '1' else 'Z';
lptd(6) <= '0' when lpdata(6) = '0' and lpdir(6) = '1' else 'Z';
lptd(7) <= '0' when lpdata(7) = '0' and lpdir(7) = '1' else 'Z';

serdata <= '0' when pa(5) = '0' else 'Z';
serclk <= '0' when pa(4) = '0' else 'Z';
seratn <= '0' when pa(3) = '0' else 'Z';
lptstrobe <= '0' when pa(2) = '0' else 'Z';

irq <= '0' when (ide_irq = '1' or pirq = '0' or err_irq_stored = '1' or clkirq = '0') and irq_enable = '1' else 'Z';
ide_irq <= ide1irq or ide2irq;

process(pci_clk,clear_irq)
begin
if clear_irq = '1' then --clear on read
err_irq_stored <= '0';
elsif pci_clk'event and pci_clk = '1' then
if perr = '0' or serr = '0' then --parity error or system error.
err_irq_stored <= '1';
end if;
end if;
end process;

buffer_en <= '0' when csel = "1000" and enable = '1' and wr = '1' else '1';

process(nclr, clk1mhz)
begin
if nclr = '0' then
nconfig <= '1';
clear_irq <= '1';
cpureset <= '1';
irq_enable <= '0'; --default disabled
elsif clk1mhz'event and clk1mhz = '0'then
clear_irq <= '0'; --used for one cycle strobe
cpureset <= '1';
if csel = "1000" and enable = '1' and wr = '0' then
nconfig <= d(0); --0 clears 1k30 fpga 1 allows programming
clear_irq <= d(1); --1 strobes and clears perr or serr interupt
irq_enable <= d(2); --enable irq's when high
cpureset <= d(3);
end if;
end if;
end process;

process
begin
wait until clk1mhz'event and clk1mhz = '0';
if csel = "1001" and enable = '1' and wr = '0' then
lpdata <= d; --printer port data latch
end if;
end process;

process
begin
wait until clk1mhz'event and clk1mhz = '0';
if csel = "1010" and enable = '1' then
lpdir <= d; --directin control register
end if;
end process;

process
begin
wait until clk1mhz'event and clk1mhz = '0';
if csel = "1011" and enable = '1' and wr = '0' then
pa(5) <= d(5); --serial port registers
pa(4) <= d(4);
pa(3) <= d(3);
pa(2) <= d(2);
end if;
end process;

d(7) <= serdata when csel = "1011" and enable = '1' and wr = '1' else
lptd(7) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(6) <= serclk when csel = "1011" and enable = '1' and wr = '1' else
lptd(6) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(5) <= lptd(5) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(4) <= lptd(4) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(3) <= lptd(3) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(2) <= lptstrobe when csel = "1011" and enable = '1' and wr = '1' else
lptd(2) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(1) <= lptd(1) when csel = "1001" and enable = '1' and wr = '1' else 'Z';
d(0) <= lptd(0) when csel = "1001" and enable = '1' and wr = '1' else 'Z';

process(nclr,clk1mhz)
begin
if nclr = '0' then
pgnt0 <= '1';
pgnt1 <= '1';
elsif clk1mhz'event and clk1mhz = '0' then
if enable = '1' then
if csel = "1101" then --PCI0 GRNT SET
pgnt0 <= '0';
end if;
if csel = "1110" then --PCI1 GRNT SET
pgnt1 <= '0';
end if;
if csel = "1100" then --PCI GNT RESET
pgnt0 <= '1';
pgnt1 <= '1';
end if;
end if;
end if;
end process;

--output shift register
--starts with a 1 for a preamble that should be used to reset the receiving shiftregister

process
begin
wait until pci_clk'event and pci_clk = '1';
shift_count <= shift_count + 1; --shift position counter
end process;

-- (comment from Jens): The first bit to be shifted is a 1 in this case
-- however, with no movement on the joysticks and no printer connected, the stream
-- would be all 1's, giving a false syncronisation on the first joystick move.
-- I am therefore assuming that the "final" source shifts out a 0.

with shift_count select
shift <= '1' when "0000",
lpt_bsy when "0001",
joya(0) when "0010",
joya(1) when "0011",
joya(2) when "0100",
joya(3) when "0101",
joya(4) when "0110",
joya(5) when "0111",
joya(6) when "1000",
joyb(0) when "1001",
joyb(1) when "1010",
joyb(2) when "1011",
joyb(3) when "1100",
joyb(4) when "1101",
joyb(5) when "1110",
joyb(6) when others;

process
begin
wait until pci_clk'event and pci_clk = '1';
shift_out <= shift; --output latch
end process;

end Behavior;



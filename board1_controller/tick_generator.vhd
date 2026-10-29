library ieee;
use ieee.std_logic_1164.all;

entity tick_generator is
    generic (
        CLK_HZ : positive := 50_000_000;
        TICK_HZ : positive := 100
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        tick_out : out std_logic
    );
end entity tick_generator;

architecture rtl of tick_generator is

    constant CYCLES_PER_TICK : positive := CLK_HZ / TICK_HZ;

    signal counter : integer range 0 to CYCLES_PER_TICK - 1 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            tick_out <= '0';

            if reset = '1' then
                counter <= 0;

            elsif counter = CYCLES_PER_TICK - 1 then
                counter <= 0;
                tick_out <= '1';

            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

end architecture rtl;

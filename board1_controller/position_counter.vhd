library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity position_counter is
    generic (
        WIDTH : positive := 16
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        step_pulse   : in  std_logic;
        direction    : in  std_logic;
        position_out : out unsigned(WIDTH - 1 downto 0)
    );
end entity position_counter;

architecture rtl of position_counter is

    signal position_reg : unsigned(WIDTH - 1 downto 0) :=
        (others => '0');

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                position_reg <= (others => '0');

            elsif step_pulse = '1' then
                if direction = '1' then
                    position_reg <= position_reg + 1;
                else
                    position_reg <= position_reg - 1;
                end if;
            end if;
        end if;
    end process;

    position_out <= position_reg;

end architecture rtl;

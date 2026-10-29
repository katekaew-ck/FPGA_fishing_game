library ieee;
use ieee.std_logic_1164.all;

entity button_debounce is
    generic (
        CLK_HZ      : positive := 50_000_000;
        DEBOUNCE_MS : positive := 10
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        button_n      : in  std_logic;

        pressed       : out std_logic;
        press_pulse   : out std_logic;
        release_pulse : out std_logic
    );
end entity button_debounce;

architecture rtl of button_debounce is

    constant STABLE_CYCLES : positive :=
        (CLK_HZ / 1000) * DEBOUNCE_MS;

    signal stable_pressed : std_logic := '0';

    signal stable_counter : integer range 0 to STABLE_CYCLES - 1 := 0;

begin

    process (clk)
        variable sampled_pressed : std_logic;
    begin
        if rising_edge(clk) then

            press_pulse   <= '0';
            release_pulse <= '0';

            if reset = '1' then
                stable_pressed <= '0';
                stable_counter <= 0;

            else
                sampled_pressed := not button_n;

                if sampled_pressed = stable_pressed then
                    stable_counter <= 0;

                elsif stable_counter = STABLE_CYCLES - 1 then
                    stable_pressed <= sampled_pressed;
                    stable_counter <= 0;

                    if sampled_pressed = '1' then
                        press_pulse <= '1';
                    else
                        release_pulse <= '1';
                    end if;

                else
                    stable_counter <= stable_counter + 1;
                end if;
            end if;
        end if;
    end process;

    pressed <= stable_pressed;

end architecture rtl;

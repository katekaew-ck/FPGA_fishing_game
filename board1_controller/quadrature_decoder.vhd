library ieee;
use ieee.std_logic_1164.all;

entity quadrature_decoder is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;

        enc_a         : in  std_logic;
        enc_b         : in  std_logic;

        step_pulse    : out std_logic;
        direction     : out std_logic;
        invalid_pulse : out std_logic
    );
end entity quadrature_decoder;

architecture rtl of quadrature_decoder is

    signal previous_ab : std_logic_vector(1 downto 0);
    signal current_ab  : std_logic_vector(1 downto 0);

    signal initialized : std_logic := '0';

    signal transition_count : integer range -3 to 3 := 0;

begin

    current_ab <= enc_a & enc_b;

    process (clk)
        variable transition_value : integer range -1 to 1;
    begin
        if rising_edge(clk) then

            step_pulse    <= '0';
            invalid_pulse <= '0';

            if reset = '1' then
                previous_ab     <= "00";
                initialized     <= '0';
                transition_count <= 0;
                direction       <= '0';

            elsif initialized = '0' then
                previous_ab <= current_ab;
                initialized <= '1';

            else
                transition_value := 0;

                case previous_ab & current_ab is

                    when "0001" |
                         "0111" |
                         "1110" |
                         "1000" =>
                        transition_value := 1;

                    when "0010" |
                         "1011" |
                         "1101" |
                         "0100" =>
                        transition_value := -1;

                    when "0000" |
                         "0101" |
                         "1010" |
                         "1111" =>
                        transition_value := 0;

                    when others =>
                        transition_value := 0;
                        transition_count <= 0;
                        invalid_pulse <= '1';

                end case;

                if transition_value = 1 then

                    if transition_count = 3 then
                        step_pulse <= '1';
                        direction <= '1';
                        transition_count <= 0;
                    else
                        transition_count <= transition_count + 1;
                    end if;

                elsif transition_value = -1 then

                    if transition_count = -3 then
                        step_pulse <= '1';
                        direction <= '0';
                        transition_count <= 0;
                    else
                        transition_count <= transition_count - 1;
                    end if;

                end if;

                previous_ab <= current_ab;
            end if;
        end if;
    end process;

end architecture rtl;

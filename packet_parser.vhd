library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity packet_parser is
    port (

        clk           : in  std_logic;
        reset         : in  std_logic;

        byte_data     : in  std_logic_vector(7 downto 0);
        byte_valid    : in  std_logic;
        frame_error   : in  std_logic;

        position_out  : out unsigned(15 downto 0);
        left_pressed  : out std_logic;
        right_pressed : out std_logic;
        packet_valid  : out std_logic

    );
end entity packet_parser;

architecture rtl of packet_parser is

    type state_type is (
        WAIT_A5, WAIT_5A,
        READ_LOW, READ_HIGH, READ_BUTTONS, READ_CHECKSUM
    );

    signal state        : state_type := WAIT_A5;
    signal low_reg      : std_logic_vector(7 downto 0) := (others => '0');
    signal high_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal buttons_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal checksum_reg : std_logic_vector(7 downto 0) := (others => '0');

begin
     process (clk)
    begin
        if rising_edge(clk) then
            packet_valid <= '0';

            if reset = '1' then
                state         <= WAIT_A5;
                low_reg       <= (others => '0');
                high_reg      <= (others => '0');
                buttons_reg   <= (others => '0');
                checksum_reg  <= (others => '0');
                position_out  <= (others => '0');
                left_pressed  <= '0';
                right_pressed <= '0';

            elsif frame_error = '1' then
                state <= WAIT_A5;

            elsif byte_valid = '1' then
                case state is

                    when WAIT_A5 =>
                        if byte_data = x"A5" then
                            state <= WAIT_5A;
                        end if;

                    when WAIT_5A =>
                        if byte_data = x"5A" then
                            checksum_reg <= x"FF";
                            state <= READ_LOW;
                        elsif byte_data /= x"A5" then
                            state <= WAIT_A5;
                        end if;

                    when READ_LOW =>
                        low_reg <= byte_data;
                        checksum_reg <= checksum_reg xor byte_data;
                        state <= READ_HIGH;

                    when READ_HIGH =>
                        high_reg <= byte_data;
                        checksum_reg <= checksum_reg xor byte_data;
                        state <= READ_BUTTONS;

                    when READ_BUTTONS =>
                        buttons_reg <= byte_data;
                        checksum_reg <= checksum_reg xor byte_data;
                        state <= READ_CHECKSUM;

                    when READ_CHECKSUM =>
                        if byte_data = checksum_reg and
                           buttons_reg(7 downto 2) = "000000" then

                            position_out <= unsigned(high_reg & low_reg);
                            left_pressed <= buttons_reg(0);
                            right_pressed <= buttons_reg(1);
                            packet_valid <= '1';
                        end if;

                        state <= WAIT_A5;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;

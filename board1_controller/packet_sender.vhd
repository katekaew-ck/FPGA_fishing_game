library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity packet_sender is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;

        send_tick       : in  std_logic;

        position_in     : in  unsigned(15 downto 0);
        left_pressed    : in  std_logic;
        right_pressed   : in  std_logic;

        tx_busy         : in  std_logic;
        tx_done         : in  std_logic;

        tx_data         : out std_logic_vector(7 downto 0);
        tx_start        : out std_logic;

        packet_busy     : out std_logic
    );
end entity packet_sender;

architecture rtl of packet_sender is

    constant HEADER_1 : std_logic_vector(7 downto 0) := x"A5";
    constant HEADER_2 : std_logic_vector(7 downto 0) := x"5A";

    type state_type is (
        IDLE,
        LOAD_BYTE,
        START_BYTE,
        WAIT_DONE
    );

    signal state : state_type := IDLE;

    signal byte_index : integer range 0 to 5 := 0;

    signal position_snapshot : unsigned(15 downto 0) :=
        (others => '0');

    signal buttons_snapshot : std_logic_vector(7 downto 0) :=
        (others => '0');

    signal checksum_snapshot : std_logic_vector(7 downto 0) :=
        (others => '0');

begin

    packet_busy <= '0' when state = IDLE else '1';

    process (clk)
        variable buttons_value : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then

            tx_start <= '0';

            if reset = '1' then
                state <= IDLE;
                byte_index <= 0;

                position_snapshot <= (others => '0');
                buttons_snapshot  <= (others => '0');
                checksum_snapshot <= (others => '0');

                tx_data <= (others => '0');

            else
                case state is

                    when IDLE =>
                        byte_index <= 0;

                        if send_tick = '1' then

                            buttons_value := (others => '0');
                            buttons_value(0) := left_pressed;
                            buttons_value(1) := right_pressed;

                            position_snapshot <= position_in;
                            buttons_snapshot  <= buttons_value;

                            checksum_snapshot <=
                                HEADER_1 xor
                                HEADER_2 xor
                                std_logic_vector(position_in(7 downto 0)) xor
                                std_logic_vector(position_in(15 downto 8)) xor
                                buttons_value;

                            state <= LOAD_BYTE;
                        end if;

                    when LOAD_BYTE =>
                        case byte_index is

                            when 0 =>
                                tx_data <= HEADER_1;

                            when 1 =>
                                tx_data <= HEADER_2;

                            when 2 =>
                                tx_data <=
                                    std_logic_vector(
                                        position_snapshot(7 downto 0)
                                    );

                            when 3 =>
                                tx_data <=
                                    std_logic_vector(
                                        position_snapshot(15 downto 8)
                                    );

                            when 4 =>
                                tx_data <= buttons_snapshot;

                            when 5 =>
                                tx_data <= checksum_snapshot;

                            when others =>
                                tx_data <= (others => '0');

                        end case;

                        state <= START_BYTE;

                    when START_BYTE =>
                        if tx_busy = '0' then
                            tx_start <= '1';
                            state <= WAIT_DONE;
                        end if;

                    when WAIT_DONE =>
                        if tx_done = '1' then

                            if byte_index = 5 then
                                byte_index <= 0;
                                state <= IDLE;
                            else
                                byte_index <= byte_index + 1;
                                state <= LOAD_BYTE;
                            end if;

                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;

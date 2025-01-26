program snake_game;

uses baseunix, termio, sysutils, dateutils;

const
    { NUMERICAL CONSTANTS }
    STDIN_FILENO = 0;
    ROWS_FIELD   = 20;
    COLS_FIELD   = 14;
    SIZE_SNAKE   = 4;
    MOVE_INTERVAL = 300;

    { RENDERING CHARS }
    WALL_SQUARE  = '#';
    EMPTY_SQUARE = ' ';
    SNAKE_HEAD   = '@';
    SNAKE_BODY_NORTH = '|';
    SNAKE_BODY_SOUTH = '|';
    SNAKE_BODY_WEST = '-';
    SNAKE_BODY_EAST = '-';
    SNAKE_BODY_SWEST = '/';
    SNAKE_BODY_SEAST = '\';
    SNAKE_BODY_NWEST = '\';
    SNAKE_BODY_NEAST = '/';
    FRUIT_SQUARE = '*';

type
    SquareType = (Empty, Wall, Snake, Fruit);

    Direction = (Up, Down, Left, Right);

    Cell = record
        row: Integer;
        col: Integer;
    end;

    Body = record
        next:  Cell;
        prev:  Cell;
        going: Direction;
    end;

    Square = record
        tag: SquareType;
        case SquareType of
            Empty: ();
            Wall:  ();
            Snake: (body: Body);
            Fruit: (fruitVal: Integer);
    end;

    Game = record
        squares:       array of array of Square;
        rows:          Integer;
        cols:          Integer;
        snake_head:    Cell;
        snake_size:    Integer;
    end;

    procedure ResetTerminal(const vGame: Game);
    begin
        Write(Chr(27), '[', vGame.rows, 'A');
        Write(Chr(27), '[', vGame.cols, 'D');
    end;

    function CompareCells(const fCell, sCell: Cell): Boolean;
    begin
        CompareCells := (fCell.row = sCell.row) and (fCell.col = sCell.col);
    end;

    procedure SetNewHead(var vGame: Game; row, col: Integer; dir: Direction);
    var
        vCell: Cell;
    begin
        vCell.row := row;
        vCell.col := col;
        vGame.squares[row][col].tag := Snake;
        vGame.squares[row][col].body.next := vGame.snake_head;
        vGame.squares[row][col].body.prev.row := -1;
        vGame.squares[row][col].body.prev.col := -1;
        vGame.squares[row][col].body.going := dir;
        vGame.squares[vGame.snake_head.row][vGame.snake_head.col].body.prev := vCell;
        vGame.snake_head := vCell;
    end;

    function IsValidSquare(const vGame: Game; const row, col: Integer): Boolean;
    begin
        if (
            (row < 0) or (row > vGame.rows - 1)
            or (col < 0) or (col > vGame.cols - 1)
        ) then
            isValidSquare := False
        else
            isValidSquare := True;
    end;

    procedure GenerateFruit(var vGame: Game);
    var
        index, i: Integer;
    begin
        index := Random((vGame.rows - 2)*(vGame.cols - 2) - vGame.snake_size);

        i := 0;
        while i <= index do
        begin
            if vGame.squares[i div vGame.cols][i mod vGame.cols].tag <> Empty then
                Inc(index);
            Inc(i);
        end;

        vGame.squares[index div vGame.cols][index mod vGame.cols].tag := Fruit;

    end;

    function GetPreviousDirection(const vGame: Game; const row, col: Integer; var dir: Direction): Boolean;
    var
        vRow, vCol: Integer;
        vSquare: Square;
    begin
        vRow := vGame.squares[row][col].body.prev.row;
        vCol := vGame.squares[row][col].body.prev.col;

        if not isValidSquare(vGame, vRow, vCol)
        then
        begin
            GetPreviousDirection := False;
            Exit;
        end;

        vSquare := vGame.squares[vRow][vCol];

        if vSquare.tag = Snake then
        begin
            dir := vSquare.body.going;
            GetPreviousDirection := True;
        end
        else
            GetPreviousDirection := False;
    end;

    function GetDirection(const vGame: Game; const row, col: Integer): Direction;
    begin
        GetDirection := vGame.squares[row][col].body.going;
    end;

    function GetNextDirection(const vGame: Game; const row, col: Integer; var dir: Direction): Boolean;
    var
        vRow, vCol: Integer;
        vSquare: Square;
    begin
        vRow := vGame.squares[row][col].body.next.row;
        vCol := vGame.squares[row][col].body.next.col;

        if (
            (vRow < 0) or (vRow > vGame.rows - 1)
            or (vCol < 0) or (vCol > vGame.cols - 1)
        ) then
        begin
            GetNextDirection := False;
            Exit;
        end;

        vSquare := vGame.squares[vRow][vCol];

        if vSquare.tag = Snake then
        begin
            dir := vSquare.body.going;
            GetNextDirection := True;
        end
        else
            GetNextDirection := False;
    end;

    function MoveSnake(var vGame: Game; const dir: Direction): Boolean;
    var
        vCell: Cell;
        vDir: Direction;
        vSquare: Square;
        i: Integer;
    begin
        vCell := vGame.snake_head;

        case dir of
            Up:    Dec(vCell.row);
            Down:  Inc(vCell.row);
            Left:  Dec(vCell.col);
            Right: Inc(vCell.col);
        end;

        { This should be a impossible case to occur }
        if not IsValidSquare(vGame, vCell.row, vCell.col)
        then
        begin
            MoveSnake := False;
            Exit;
        end;

        if vGame.squares[vCell.row][vCell.col].tag = Wall
        then
        begin
            MoveSnake := False;
            Exit;
        end;

        if vGame.squares[vCell.row][vCell.col].tag = Snake
        then
        begin
            { Handle the case when the snake hit itself }
            if GetNextDirection(vGame, vCell.row, vCell.col, vDir) then
            begin
                MoveSnake := False;
                Exit;
            end
            { Handle the case when the snake head take the place of the tail }
            else
            begin
                GetPreviousDirection(vGame, vCell.row, vCell.col, vDir);
                case vDir of
                    Up:
                        begin
                            vGame.squares[vCell.row - 1][vCell.col].body.next.row := -1;
                            vGame.squares[vCell.row - 1][vCell.col].body.next.col := -1;
                        end;
                    Down:
                        begin
                            vGame.squares[vCell.row + 1][vCell.col].body.next.row := -1;
                            vGame.squares[vCell.row + 1][vCell.col].body.next.col := -1;
                        end;
                    Left:
                        begin
                            vGame.squares[vCell.row][vCell.col - 1].body.next.row := -1;
                            vGame.squares[vCell.row][vCell.col - 1].body.next.col := -1;
                        end;
                    Right:
                        begin
                            vGame.squares[vCell.row][vCell.col + 1].body.next.row := -1;
                            vGame.squares[vCell.row][vCell.col + 1].body.next.col := -1;
                        end;
                end;
                SetNewHead(vGame, vCell.row, vCell.col, dir);
                MoveSnake := True;
                Exit;
            end;
        end;

        { Handle the case when the snake eats a fruit }
        if vGame.squares[vCell.row][vCell.col].tag = Fruit
        then
        begin
            SetNewHead(vGame, vCell.row, vCell.col, dir);

            Inc(vGame.snake_size);

            GenerateFruit(vGame);

            MoveSnake := True;
            Exit;
        end;

        { Handle the case when the snake moves to a empty cell }
        if vGame.squares[vCell.row][vCell.col].tag = Empty
        then
        begin
            SetNewHead(vGame, vCell.row, vCell.col, dir);

            vSquare := vGame.squares[vGame.snake_head.row][vGame.snake_head.col];

            for i := 2 to vGame.snake_size do
                vSquare := vGame.squares[vSquare.body.next.row][vSquare.body.next.col];

            vGame.squares[vSquare.body.next.row][vSquare.body.next.col].tag := Empty;

            moveSnake := True;
        end;
    end;

    procedure PrintGame(const vGame: Game);
    var
        i, j: Integer;
        pDir, dir: Direction;
    begin
        for i := 0 to vGame.rows - 1 do
        begin
            for j := 0 to vGame.cols - 1 do
            begin
                case vGame.squares[i][j].tag of
                    Wall:  Write(WALL_SQUARE);
                    Empty: Write(EMPTY_SQUARE);
                    Fruit: Write(FRUIT_SQUARE);
                    Snake:
                        begin
                            if not GetPreviousDirection(vGame, i, j, pDir) then
                                Write(SNAKE_HEAD)
                            else
                            begin
                                dir := GetDirection(vGame, i, j);
                                case pDir of
                                    Up:
                                        case dir of
                                            Up, Down: Write(SNAKE_BODY_NORTH);
                                            Left:     Write(SNAKE_BODY_NWEST);
                                            Right:    Write(SNAKE_BODY_NEAST);
                                        end;
                                    Down:
                                        case dir of
                                            Up, Down: Write(SNAKE_BODY_SOUTH);
                                            Left:     Write(SNAKE_BODY_SWEST);
                                            Right:    Write(SNAKE_BODY_SEAST);
                                        end;
                                    Left:
                                        case dir of
                                            Left, Right: Write(SNAKE_BODY_EAST);
                                            Up:          Write(SNAKE_BODY_NWEST);
                                            Down:        Write(SNAKE_BODY_SWEST);
                                        end;
                                    Right:
                                        case dir of
                                            Left, Right: Write(SNAKE_BODY_WEST);
                                            Up:          Write(SNAKE_BODY_NEAST);
                                            Down:        Write(SNAKE_BODY_SEAST);
                                        end;
                                end;
                            end;
                        end;
                end;
            end;
            Write(#10);
        end;
    end;

    procedure SetSquareToSnake(var vGame: Game; const row, col, pRow, pCol, nRow, nCol: Integer; const going: Direction);
    begin
        vGame.squares[row][col].tag           := Snake;
        vGame.squares[row][col].body.prev.row := pRow;
        vGame.squares[row][col].body.prev.col := pCol;
        vGame.squares[row][col].body.next.row := nRow;
        vGame.squares[row][col].body.next.col := nCol;
        vGame.squares[row][col].body.going    := going;
    end;

    procedure GameStart(var vGame: Game; rows, cols, size: Integer);
    var
        i, j, k, pRow, pCol: Integer;
    begin
        vGame.rows := rows;
        vGame.cols := cols;
        SetLength(vGame.squares, rows, cols);

        for i := 0 to rows - 1 do
            for j := 0 to cols - 1 do
            begin
                if (i = 0) or (i = rows - 1) or
                (j = 0) or (j = cols - 1) then
                    vGame.squares[i][j].tag := Wall
                else
                    vGame.squares[i][j].tag := Empty;
            end;

        vGame.snake_size := size;

        vGame.snake_head.row := (rows div 2);
        vGame.snake_head.col := (cols div 2);

        pRow := -1;
        pCol := -1;

        for k := 0 to size - 1 do
        begin
            setSquareToSnake(
                vGame,
                (rows div 2) + k, (cols div 2),
                pRow, pCol,
                (rows div 2) + k + 1, (cols div 2),
                Up
            );
            pRow := (rows div 2) + k;
            pCol := (cols div 2);
        end;

        GenerateFruit(vGame);
    end;

var
    oldTerm, newTerm: Termios;
    buffer: array[0..255] of Char;
    vGame: Game;
    quit: Boolean;
    fdSet: TFDSet;
    dir: Direction;
    lastMoveTime, currentTime: TDateTime;
    timeout: TTimeval;

begin
    Randomize;

    if IsATTY(STDIN_FILENO) = 0 then
    begin
        WriteLn('ERROR: not a terminal');
        Halt(1);
    end;
    TCGetAttr(STDIN_FILENO, oldTerm);
    TCGetAttr(STDIN_FILENO, newTerm);
    newTerm.c_lflag := newTerm.c_lflag and (not (ICANON or ECHO));
    newTerm.c_cc[VMIN] := 1;
    newTerm.c_cc[VTIME] := 0;
    TCSetAttr(STDIN_FILENO, TCSAFLUSH, newTerm);

    GameStart(vGame, ROWS_FIELD, COLS_FIELD, SIZE_SNAKE);
    PrintGame(vGame);
    quit := False;

    lastMoveTime := Now;

    while not quit do
    begin
        fpFD_ZERO(fdSet);
        fpFD_SET(STDIN_FILENO, fdSet);
        timeout.tv_sec := 0;
        timeout.tv_usec := MOVE_INTERVAL * 1000 + 50000;

        dir := GetDirection(vGame, vGame.snake_head.row, vGame.snake_head.col);
        if fpSelect(STDIN_FILENO + 1, @fdSet, nil, nil, @timeout) > 0 then
        begin
            fpRead(STDIN_FILENO, buffer, SizeOf(buffer));
            case buffer[0] of
                'q': break;
                'w':
                    begin
                        if dir <> Down then dir := Up
                    end;
                'a':
                    begin
                        if dir <> Right then dir := Left
                    end;
                's':
                    begin
                        if dir <> Up then dir := Down
                    end;
                'd':
                    begin
                        if dir <> Left then dir := Right
                    end;
            end;
        end;
        currentTime := Now;
        if MilliSecondsBetween(lastMoveTime, currentTime) < MOVE_INTERVAL then
        begin
            Sleep(MOVE_INTERVAL - MilliSecondsBetween(lastMoveTime, currentTime));
        end;
        quit := not MoveSnake(vGame, dir);
        lastMoveTime := Now;
        ResetTerminal(vGame);
        PrintGame(vGame);
    end;

    TCSetAttr(STDIN_FILENO, TCSANOW, oldTerm);
end.

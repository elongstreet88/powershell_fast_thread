# Overview
A fast threading wrapper for runspace powershell multi-threading.
There are a few others out there, but i found it painful to have to continually pass functions, variables, and other limitations, so wrote my own.

This handles jobs in parallel and tidys up must of the boiler plate.
It also allows you to access variables in curent scope automatically which is handy.

This is blazing fast and used for processing thousands of jobs at once.
Memory and CPU will run pretty hot as its very greedy, so tweak `maxThreads` as needed.

# How to run
```powershell
# Dot source the file
. ./Invoke-FastThread.ps1

#Get your objects
$ids = $(1..10)

#You can use local variables in the scripblock automatically
$my_message = "result: "

#You can use local functions too!
function test($id)
{
    write-host ("function test! - " + $id)
}

#Fire it up!
$results = @()
$results += Invoke-FastThread -objects $ids -maxThreads 32 -scriptblock {
    #the current record is accessible via [$_]
    $id = $_

    #Sleep to demonstrate threading
    start-sleep -milliseconds (Get-Random -Maximum 100)

    #Can access variables from current scope automatically
    write-host ($my_message + $id)

    #Can also use functions defined in scope automatically
    test($id)

    #Return results as normal
    return $id
}

<## OUTPUT

result: 3
result: 4
result: 5
result: 1
function test! - 3
result: 6
function test! - 4
function test! - 5
function test! - 1
result: 8
result: 7
function test! - 6
[0/10] jobs completed
function test! - 8
function test! - 7
result: 2
function test! - 2
result: 9
function test! - 9
result: 10
function test! - 10
[1/10] jobs completed
[all jobs completed]

##>
```
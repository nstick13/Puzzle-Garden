import Foundation

// Offline generator for the bundled no-guess puzzle bank.
// Compiled + run by tools/build_bank.sh (NOT part of the app target).
//
// Usage: bankgen <size 5-9> <count> <outputPath>
// Emits boards_NxN.json: { "size": N, "boards": [ { "regions": [[…]], "solution": [[…]] }, … ] }
// Every board is unique and verified fully no-guess solvable before it's written.

let args = CommandLine.arguments
guard args.count >= 4, let size = Int(args[1]), let count = Int(args[2]),
      let grid = GridSize(rawValue: size) else {
    FileHandle.standardError.write(Data("usage: bankgen <size 5-9> <count> <outputPath>\n".utf8))
    exit(2)
}
let outPath = args[3]

struct BankBoard: Encodable { let regions: [[Int]]; let solution: [[Int]] }
struct BankFile: Encodable { let size: Int; let boards: [BankBoard] }

var boards: [BankBoard] = []
var seen = Set<String>()
var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
var attempts = 0
let start = Date()

while boards.count < count {
    attempts += 1
    // LCG step → well-spread, distinct seeds.
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    // generateLive bypasses the bank (which is empty here anyway) and does real generation.
    guard let p = PuzzleGenerator.generateLive(difficulty: grid, seed: seed) else { continue }
    // Belt-and-braces: every banked board MUST be fully no-guess solvable.
    guard LogicSolver.grade(regions: p.regions, n: size).fullySolved else { continue }
    // Dedup by region signature (a fully-fair board's solution is implied by its regions).
    let sig = p.regions.map { $0.map(String.init).joined() }.joined(separator: "|")
    guard seen.insert(sig).inserted else { continue }

    boards.append(BankBoard(regions: p.regions, solution: p.solution))
    if boards.count % 100 == 0 {
        let e = Date().timeIntervalSince(start)
        FileHandle.standardError.write(Data("  \(boards.count)/\(count)  (\(Int(e))s, \(attempts) attempts)\n".utf8))
    }
}

let data = try! JSONEncoder().encode(BankFile(size: size, boards: boards))
try! data.write(to: URL(fileURLWithPath: outPath))
let e = Date().timeIntervalSince(start)
print("✓ \(boards.count) unique \(size)×\(size) boards → \(outPath)  (\(data.count) bytes, \(Int(e))s, \(attempts) attempts)")

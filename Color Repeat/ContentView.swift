//
//  ContentView.swift
//  Color Repeat
//
//  Created by Jada Brunson on 9/10/24.
//

import SwiftUI
import CoreMotion
import FirebaseFirestore // Import Firestore

struct ContentView: View {
    @State private var currentSequence: [Color] = []
    @State private var userSequence: [Color] = []
    @State private var score: Int = 0
    @State private var showingSequence = false
    @State private var gameActive = false
    @State private var timeRemaining: Int = 60
    @State private var bonusTimeRemaining: Int = 5
    @State private var isBonusRound = false
    @State private var bonusPointsEarned = false
    @State private var feedbackText: String? = nil
    @State private var shakeDetected = false
    @State private var bonusPointsAwarded = false
    @State private var showFinalScore = false // To trigger final score screen
    @State private var showPastScores = false
    @State private var gameStarted = false // Start page flag
    @State private var pastScores: [(score: Int, date: Date)] = [] // Store fetched scores
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]

    // Firestore reference
    let db = Firestore.firestore()

    let motionManager = CMMotionManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Black background

            if !gameStarted {
                // Start Page
                VStack {
                    Text("Welcome to Color Repeat!")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()

                    Text("Memorize the color sequence and repeat it! You have 60 seconds to score as many points as you can. A bonus round will let you shake the device for extra points.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    Button("Start Game") {
                        startNewGame()
                    }
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
            } else if showFinalScore {
                VStack {
                    Text("Game Over")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()

                    Text("Your total score: \(score)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    Button("Play Again") {
                        // Start a completely new game, resetting all states
                        resetGame()
                        startNewGame()
                    }
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)

                    Button("View Past Scores") {
                        loadPastScores()
                        showPastScores.toggle()
                    }
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)

                    if showPastScores {
                        List(pastScores, id: \.date) { scoreEntry in
                            VStack(alignment: .leading) {
                                Text("Score: \(scoreEntry.score)")
                                    .font(.headline)
                                Text("Date: \(formatDate(scoreEntry.date))")
                                    .font(.subheadline)
                            }
                        }
                        .frame(height: 200)
                    }
                }
            } else if gameActive {
                VStack {
                    if isBonusRound {
                        Text("Bonus Round: Shake for 3 extra points!")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                            .padding()

                        Text("Time left: \(bonusTimeRemaining)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()

                        if bonusPointsEarned {
                            Text("Bonus points earned!")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding()
                        }
                    } else {
                        Text("Time remaining: \(timeRemaining)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()

                        if let feedback = feedbackText {
                            Text(feedback)
                                .font(.headline)
                                .foregroundColor(feedback == "Correct!" ? .green : .red)
                                .padding()
                        }

                        if showingSequence {
                            Text("Memorize the sequence!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()

                            HStack {
                                ForEach(currentSequence, id: \.self) { color in
                                    Rectangle()
                                        .fill(color)
                                        .frame(width: 50, height: 50)
                                        .padding()
                                }
                            }

                            Button("Hide Sequence") {
                                showingSequence = false
                            }
                            .padding()
                        } else {
                            Text("Repeat the sequence by tapping the colors!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()

                            // GeometryReader to adjust button size based on screen size
                            GeometryReader { geometry in
                                let buttonSize = geometry.size.width / 4

                                VStack {
                                    HStack {
                                        ForEach(0..<3) { index in
                                            Button(action: {
                                                userTapped(color: colors[index])
                                            }) {
                                                Circle()
                                                    .fill(colors[index])
                                                    .frame(width: buttonSize, height: buttonSize)
                                                    .padding(5)
                                            }
                                        }
                                    }
                                    HStack {
                                        ForEach(3..<colors.count) { index in
                                            Button(action: {
                                                userTapped(color: colors[index])
                                            }) {
                                                Circle()
                                                    .fill(colors[index])
                                                    .frame(width: buttonSize, height: buttonSize)
                                                    .padding(5)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                }
            }
        }
        .onAppear(perform: {
            resetGame() // Ensure the game starts cleanly
        })
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if gameActive && !isBonusRound {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    startBonusRound()
                }
            } else if isBonusRound {
                if bonusTimeRemaining > 0 {
                    bonusTimeRemaining -= 1
                    if shakeDetected && !bonusPointsAwarded {
                        score += 3
                        bonusPointsEarned = true
                        bonusPointsAwarded = true
                        vibratePhone()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            bonusPointsEarned = false
                        }
                    }
                } else {
                    endGame()  // End the game after the bonus round
                }
            }
        }
    }

    func resetGame() {
        // Reset all the states for a new game
        score = 0
        timeRemaining = 60
        bonusTimeRemaining = 5
        gameActive = false
        isBonusRound = false
        bonusPointsAwarded = false
        feedbackText = nil
        showFinalScore = false
        gameStarted = false
    }

    func startNewGame() {
        gameStarted = true
        gameActive = true
        currentSequence = generateRandomSequence()
    }

    func generateRandomSequence() -> [Color] {
        var sequence: [Color] = []
        for _ in 0..<4 {
            sequence.append(colors.randomElement()!)
        }
        return sequence
    }

    func userTapped(color: Color) {
        userSequence.append(color)
        if userSequence.count == currentSequence.count {
            checkUserSequence()
        }
    }

    func checkUserSequence() {
        if userSequence == currentSequence {
            score += 1
            feedbackText = "Correct!"
        } else {
            feedbackText = "Incorrect!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            feedbackText = nil
            currentSequence = generateRandomSequence()
            userSequence = []
            showingSequence = true
        }
    }

    func startBonusRound() {
        isBonusRound = true
        bonusTimeRemaining = 5
    }

    func endGame() {
        gameActive = false
        if !bonusPointsAwarded {
            saveScoreToFirebase()  // Save score only once
            showFinalScore = true  // Trigger final score screen
        }
    }

    func saveScoreToFirebase() {
        let scoreData: [String: Any] = [
            "score": score,
            "date": Timestamp(date: Date())
        ]

        db.collection("scores").addDocument(data: scoreData) { error in
            if let error = error {
                print("Error saving score to Firestore: \(error.localizedDescription)")
            } else {
                print("Score saved successfully!")
            }
        }
    }

    // Fetch past scores from Firestore
    func loadPastScores() {
        db.collection("scores").order(by: "date", descending: true).getDocuments { snapshot, error in
            if let error = error {
                print("Error loading scores: \(error.localizedDescription)")
            } else if let snapshot = snapshot {
                self.pastScores = snapshot.documents.map { document in
                    let score = document.data()["score"] as? Int ?? 0
                    let timestamp = document.data()["date"] as? Timestamp
                    let date = timestamp?.dateValue() ?? Date()
                    return (score: score, date: date)
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func startShakeDetection() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.2
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
                if let data = data {
                    let acceleration = data.acceleration
                    if abs(acceleration.x) > 2.5 || abs(acceleration.y) > 2.5 || abs(acceleration.z) > 2.5 {
                        self.shakeDetected = true
                    }
                }
            }
        }
    }

    func vibratePhone() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

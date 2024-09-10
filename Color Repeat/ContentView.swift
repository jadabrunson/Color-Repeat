//
//  ContentView.swift
//  Color Repeat
//
//  Created by Jada Brunson on 9/10/24.
//

import SwiftUI
import CoreMotion
import SwiftData
import UIKit

struct ContentView: View {
    @State private var currentSequence: [Color] = []
    @State private var userSequence: [Color] = []
    @State private var score: Int = 0
    @State private var showingSequence = false
    @State private var gameActive = false
    @State private var timeRemaining: Int = 60
    @State private var bonusTimeRemaining: Int = 5
    @State private var isBonusRound = false
    @State private var showPastScores = false
    @State private var gameStartTime: Date?
    @State private var userHasInputSequence = false
    @State private var showStartScreen = true
    @State private var feedbackText: String? = nil // To show "Correct" or "Incorrect"
    @State private var allowUserInput = false // Ensures the user must input the sequence
    @State private var shakeDetected = false // To detect shake in the bonus round

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
    let colorNames = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple"]
    
    let motionManager = CMMotionManager()

    @Environment(\.modelContext) private var context
    @Query private var items: [Item] // Query for the Item model

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Black background for the game

            if showStartScreen {
                VStack {
                    Text("Welcome to Color Repeat")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()

                    Text("Remember the sequence and repeat it by tapping the colors!")
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
                                allowUserInput = true // Allow user input after hiding the sequence
                            }
                            .padding()
                        } else if allowUserInput {
                            Text("Repeat the sequence by tapping the colors!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()

                            // GeometryReader to adjust button size based on screen size
                            GeometryReader { geometry in
                                let buttonSize = geometry.size.width / 4 // Adjust button size based on screen width

                                VStack {
                                    // First row (3 buttons)
                                    HStack {
                                        ForEach(0..<3) { index in
                                            Button(action: {
                                                self.userTapped(color: colors[index])
                                            }) {
                                                Circle()
                                                    .fill(colors[index])
                                                    .frame(width: buttonSize, height: buttonSize)
                                                    .padding(5)
                                            }
                                        }
                                    }

                                    // Second row (3 buttons)
                                    HStack {
                                        ForEach(3..<colors.count) { index in
                                            Button(action: {
                                                self.userTapped(color: colors[index])
                                            }) {
                                                Circle()
                                                    .fill(colors[index])
                                                    .frame(width: buttonSize, height: buttonSize)
                                                    .padding(5)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center) // Center the buttons
                            }
                            .frame(maxHeight: .infinity, alignment: .center) // Center the buttons vertically

                            if userHasInputSequence {
                                Button("Done") {
                                    checkUserSequence()
                                }
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            } else {
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
                        startNewGame()
                    }
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)

                    Button("View Past Scores") {
                        showPastScores.toggle()
                    }
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }

                if showPastScores {
                    VStack {
                        Text("Past Scores")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()

                        List {
                            ForEach(items) { item in
                                HStack {
                                    Text("\(item.points) points")
                                    Spacer()
                                    Text("\(item.date.formatted())")
                                }
                            }
                        }
                        .frame(height: 300)
                        
                        Button("Back to Game") {
                            showPastScores = false
                        }
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .onAppear(perform: setupNewGame)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard gameActive else { return }
            if !isBonusRound {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    startBonusRound()
                }
            } else {
                if bonusTimeRemaining > 0 {
                    bonusTimeRemaining -= 1
                    if shakeDetected {
                        score += 3 // Add bonus points for shake
                        shakeDetected = false // Reset shake detection
                        vibratePhone() // Trigger stronger vibration when points are added
                    }
                } else {
                    endGame()
                }
            }
        }
    }

    func startNewGame() {
        score = 0
        timeRemaining = 60
        bonusTimeRemaining = 5
        gameStartTime = Date()
        showingSequence = true
        gameActive = true
        isBonusRound = false
        userHasInputSequence = false
        feedbackText = nil // Clear feedback when starting a new game
        showStartScreen = false
        setupNewGame()
        startShakeDetection() // Start detecting shakes
    }

    func setupNewGame() {
        currentSequence = generateRandomSequence()
        userSequence = []
        userHasInputSequence = false
        showingSequence = true // Display the new sequence immediately
        allowUserInput = false // Disable user input until sequence is hidden
    }

    func generateRandomSequence() -> [Color] {
        var sequence: [Color] = []
        for _ in 0..<4 {  // You can adjust the length of the sequence as needed
            sequence.append(colors.randomElement()!)
        }
        return sequence
    }

    func userTapped(color: Color) {
        guard !showingSequence && allowUserInput && gameActive else { return }

        userSequence.append(color)

        if userSequence.count == currentSequence.count {
            userHasInputSequence = true  // Show the "Done" button after the sequence is input
        }
    }

    func checkUserSequence() {
        allowUserInput = false // Prevent further input until the next sequence
        if userSequence == currentSequence {
            score += 1  // Increment the score if the sequence is correct
            feedbackText = "Correct!"
        } else {
            feedbackText = "Incorrect!"
        }
        
        // Show feedback for 2 seconds, then move to the next sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            feedbackText = nil
            setupNewGame()  // Display a new sequence after feedback
        }
    }

    func startBonusRound() {
        isBonusRound = true
        bonusTimeRemaining = 5
    }

    func endGame() {
        gameActive = false
        stopShakeDetection()
        saveScore()
    }

    func saveScore() {
        let newItem = Item(points: score) // Save the total score after the game ends
        context.insert(newItem)
        do {
            try context.save()
        } catch {
            print("Failed to save item: \(error)")
        }
    }

    // Start detecting shakes using the accelerometer
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

    // Stop detecting shakes
    func stopShakeDetection() {
        motionManager.stopAccelerometerUpdates()
    }
    
    // Trigger stronger haptic feedback (vibration)
       func vibratePhone() {
           let generator = UINotificationFeedbackGenerator()
           generator.notificationOccurred(.error)  // can use `.success`, `.warning`, or `.error` for different strengths
       }
   }

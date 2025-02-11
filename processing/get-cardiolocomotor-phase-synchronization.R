# The MIT License (MIT)
# Copyright (c) 2016 University of Applied Sciences Bremen
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Version 2.0

# !!! Set working directory to file directory

# Remove all variables
rm(list = ls(all = T))  

# Load libraries
library(flow)
library(zoom)

# User input
root.directory.path <- readline("Source data directory (with / at the end) > ") 
first.name <- readline("First name of the participant > ")
last.name <- readline("Last name of the participant > ")
activity <- readline("Activity of the session > ")
ecg.data.file.name <- readline("Filename of the file with ECG data (without .csv) > ")
kinematic.data.file.name.1 <- readline("Filename of the first file with kinematic data (without .csv) > ")
kinematic.data.file.name.2 <- readline("Filename of the second file with kinematic data (optional / without .csv) > ")
time.window.s <- as.numeric(readline("Time window for the index calculation (s) > "))
if(is.na(time.window.s)) time.window.s = 30

# Set directory paths
source("./code-snippets/set-directory-paths.R")

# List self report names
self.report.file.names <- list.files(path = raw.data.directory.path, pattern = "self-report.csv", recursive = TRUE)

for (self.report.file.name in self.report.file.names) {
  
  source("./code-snippets/get-session-start.R")
  
  # Load self report data
  self.report.data <- read.csv(paste(raw.data.directory.path, self.report.file.name, sep = ""), comment.char = "#")
  
  # Loop measurements
  for(i in 1:nrow(self.report.data)) {
    
    source("./code-snippets/get-self-report-times.R")
    
    stride.data.file.path.1 <- paste(processed.data.directory.path, date.directory, kinematic.data.file.name.1, "-stride-data-", i,  ".csv", sep = "")
    if(kinematic.data.file.name.2 != "") stride.data.file.path.2 <- paste(processed.data.directory.path, date.directory, kinematic.data.file.name.2, "-stride-data-", i,  ".csv", sep = "")
    kubios.hrv.data.file.path <- paste(processed.data.directory.path, date.directory, ecg.data.file.name, "-", i, "_hrv.txt", sep="")
  
    if(file.exists(stride.data.file.path.1) & file.exists(kubios.hrv.data.file.path)) {
      
      # Set stride times
      stride.data.1 <- read.csv(stride.data.file.path.1, skip = 0)
      multiplier <- 2
      if(kinematic.data.file.name.2 != "") {
        if(file.exists(stride.data.file.path.2)) {
          stride.data.2 <- read.csv(stride.data.file.path.2, skip = 0)
          stride.data.1 <- rbind(stride.data.1, stride.data.2)
          multiplier <- 1
        }
      }
      stride.data.1 <- stride.data.1[order(stride.data.1[, 1]),]
      stride.times <- stride.data.1[, 1] / 1000
      
      # Load heart beat times
      source("./code-snippets/get-kubios-hrv-data.R")
      heart.beat.times <- c(kubios.hrv.data[1, 1] - kubios.hrv.data[1, 2], kubios.hrv.data[, 1])
      
      spm <- c(NA, 60 * multiplier / diff(stride.times)) 
      bpm <- c(NA, 60 / diff(heart.beat.times))
      
      time.range.s <- c(round(min(heart.beat.times)) - 10, round(max(heart.beat.times)) + 10)
      y.lim <- c(min(mean(spm, na.rm = TRUE) - sd(spm, na.rm = TRUE) * 2, mean(bpm, na.rm = TRUE) - sd(bpm, na.rm = TRUE) * 2), max(mean(spm, na.rm = TRUE) + sd(spm, na.rm = TRUE) * 2, mean(bpm, na.rm = TRUE) + sd(bpm, na.rm = TRUE) * 2))
      
      # Plot
      par(mfcol = c(3, 1), mar = c(3.5, 4, 2, 4) + 0.1, mgp = c(2.5, 1, 0))
      
      # SPM vs. BPM 
      plot(stride.times, spm, xlab = "", ylab = "Mean Step & Mean HR", xaxt = "n", xlim = time.range.s, ylim = y.lim, xaxs = "i", pch = 23, bg = rgb(0/255, 152/255, 199/255))
      points(heart.beat.times, bpm, pch = 21, bg = rgb(229/255, 66/255, 66/255))
      abline(v = seq(time.range.s[1], time.range.s[2], time.window.s), lty = "dashed", col = rgb(186/255, 187/255, 194/255))
      axis(1, at = seq(time.range.s[1], time.range.s[2], time.window.s), labels = seq(time.range.s[1], time.range.s[2], time.window.s), las = 1)
      legend("topright", c("SPM", "BPM"), pch = c(23, 21), pt.bg = c(rgb(0/255, 152/255, 199/255), rgb(229/255, 66/255, 66/255)), bg = "white")
      box()
      
      title(paste(format(session.start + activity.start.ms / 1000, "%m/%d/%Y %H:%M", tz = "CET"), " #", i, sep = ""))
      
      # Stroboscopic Technique
      instantaneous.phase.data <- ComputeInstantaneousPhases(heart.beat.times, stride.times)
      fi <- instantaneous.phase.data[, 2] # instantaneous phases
      psi <- (fi %% (2 * pi)) / (2 * pi) # relative phases
      cls.phase.data <- data.frame(timestamp.ms = round(instantaneous.phase.data[, 1] * 1000, 3), fi = round(fi, 3), psi = round(psi, 3))
      rm(instantaneous.phase.data, fi, psi)
      
      y.lim <- c(0, 1)
      plot(cls.phase.data[, 1] / 1000, cls.phase.data[, 3], xlab = "", ylab = expression("Rel. Phase " ~ Psi(t)), xaxt = "n",  yaxt = "n", xlim = time.range.s, xaxs = "i", yaxs = "i", ylim = y.lim, pch = 24, bg = rgb(96/255, 65/255, 79/255))
      abline(v = seq(time.range.s[1], time.range.s[2], time.window.s), lty = "dashed", col = rgb(186/255, 187/255, 194/255))
      axis(1, at = seq(time.range.s[1], time.range.s[2], time.window.s), labels = seq(time.range.s[1], time.range.s[2], time.window.s), las = 1)
      axis(2, at = seq(y.lim[1], y.lim[2], .2), labels = seq(y.lim[1], y.lim[2], .2))
      box()
      
      # Compute Indexes
      timestamps <- seq(min(cls.phase.data[, 1] / 1000) + time.window.s/2, max(cls.phase.data[, 1] / 1000) - time.window.s/2, 1)
      phase.coherence.indexes <- c()
      normalized.shannon.entropy.indexes <- c()
      for (timestamp in timestamps) {
        phase.coherence.indexes <- c(phase.coherence.indexes, ComputePhaseCoherenceIndex(cls.phase.data[, 1] / 1000, cls.phase.data[, 3], timestamp, time.window.s))
        normalized.shannon.entropy.indexes <- c(normalized.shannon.entropy.indexes, ComputeNormalizedShannonEntropyIndex(cls.phase.data[, 1]/ 1000, cls.phase.data[, 3], timestamp, time.window.s)) 
      }
      rm(timestamp)
      
      cls.index.data <- data.frame(timestamp.ms = timestamps * 1000, pcoi = round(phase.coherence.indexes, 3), nsei = round(normalized.shannon.entropy.indexes, 3))
      cls.index.data <- cls.index.data[cls.index.data[, 1] / 1000 > min(heart.beat.times) & cls.index.data[, 1] / 1000 < max(heart.beat.times), ]
      rm(timestamps, phase.coherence.indexes, normalized.shannon.entropy.indexes)
      
      plot(cls.index.data[, 1] / 1000, cls.index.data[, 3], type = "l", xlab = "Time (s)", ylab = "Indexes", xaxt = "n",  yaxt = "n", xlim = time.range.s, xaxs = "i", yaxs = "i", ylim = y.lim, col = rgb(0/255, 152/255, 199/255))
      lines(cls.index.data[, 1] / 1000, cls.index.data[, 2], lty = 2)
      abline(v = seq(time.range.s[1], time.range.s[2], time.window.s), lty = "dashed", col = rgb(186/255, 187/255, 194/255))
      axis(1, at = seq(time.range.s[1], time.range.s[2], time.window.s), labels = seq(time.range.s[1], time.range.s[2], time.window.s), las = 1)
      axis(2, at = seq(y.lim[1], y.lim[2], .2), labels = seq(y.lim[1], y.lim[2], .2))
      legend("topright", c("PCoI", "NSEI"), lty = c("dashed", "solid"),  col = c("black", rgb(0/255, 152/255, 199/255)), bg = "white")
      box()
      zm()
      
      # Print synchronization features
      print("---")
      print(paste("Mean normalized Shannon Entropy Index:", round(mean(cls.index.data[, 3], na.rm = TRUE), 2)))
      print(paste("Mean Coherence Index:", round(mean(cls.index.data[, 2], na.rm = TRUE), 2)))
      
      # Write to csv file
      if(!dir.exists(paste(processed.data.directory.path, date.directory, sep =""))) {
        dir.create(paste(processed.data.directory.path, date.directory, sep =""), recursive = T)
      }
      write.csv(cls.index.data, paste(processed.data.directory.path, date.directory, "cls-index-data-", i, ".csv", sep = ""), row.names = F)
      write.csv(cls.phase.data, paste(processed.data.directory.path, date.directory, "cls-phase-data-", i, ".csv", sep = ""), row.names = F)
      
      print("---")
      print(paste("Wrote", paste("cls-index-data-", i, ".csv", sep = ""), "in", paste(processed.data.directory.path, date.directory, sep ="")))
      print(paste("Wrote", paste("cls-phase-data-", i, ".csv", sep = ""), "in", paste(processed.data.directory.path, date.directory, sep ="")))
      
    } else {
      print("---")
      print(paste("File not found:", ecg.data.file.name))
      print("or")
      print(paste("File not found:", kinematic.data.file.name.1))
    }
    readline("Next > ")
  }
}
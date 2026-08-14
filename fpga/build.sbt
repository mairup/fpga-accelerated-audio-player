scalaVersion := "2.13.13"

addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % "3.6.1" cross CrossVersion.full)

libraryDependencies ++= Seq(
  "edu.berkeley.cs" %% "chisel3" % "3.6.1",
  "edu.berkeley.cs" %% "chiseltest" % "0.6.1" % "test"
)

scalacOptions ++= Seq(
  "-language:reflectiveCalls",
  "-deprecation",
  "-feature",
  "-Xcheckinit",
  "-Xsource:3"
)

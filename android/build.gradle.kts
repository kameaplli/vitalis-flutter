allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Register afterEvaluate BEFORE evaluationDependsOn triggers child project evaluation.
// This ensures printing's hardcoded compileSdkVersion 30 is patched to 35.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.compileSdk = 35
    }
}

// Must come after the afterEvaluate block above so callbacks are registered first.
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
    .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val projectDir = project.projectDir.absolutePath
    val rootDir = rootProject.rootDir.absolutePath

    // Check if the subproject is on the same drive as the root project (Windows specific).
    // If they are on different drives, moving the build directory to the root project's drive
    // causes "different roots" errors in Android Gradle Plugin's GenerateTestConfig task.
    val isSameDrive = if (projectDir.contains(":") && rootDir.contains(":")) {
        projectDir.substringBefore(":").equals(rootDir.substringBefore(":"), ignoreCase = true)
    } else {
        projectDir.startsWith(rootDir)
    }

    if (isSameDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    } else {
        // For plugins located on a different drive (e.g., in the Pub cache on C: while the project is on D:),
        // keep the build directory local to the project directory to avoid the "different roots" error.
        project.layout.buildDirectory.value(project.layout.projectDirectory.dir("build"))
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

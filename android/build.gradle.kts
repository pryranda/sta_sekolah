allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Force compileSdk 36 untuk SEMUA plugin (fix file_picker error)
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.getByName("android").let { android ->
                (android as com.android.build.gradle.BaseExtension).apply {
                    compileSdkVersion(36)
                }
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
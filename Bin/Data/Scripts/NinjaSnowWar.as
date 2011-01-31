// Partial remake of NinjaSnowWar in script

#include "Scripts/LightFlash.as"
#include "Scripts/Ninja.as"
#include "Scripts/Potion.as"
#include "Scripts/SnowBall.as"
#include "Scripts/SnowCrate.as"

const float mouseSensitivity = 0.125;
const float cameraMinDist = 25;
const float cameraMaxDist = 500;
const float cameraSafetyDist = 30;
const int playerHealth = 20;

Scene@ gameScene;
Camera@ gameCamera;
Text@ scoreText;
Text@ hiscoreText;
Text@ messageText;
BorderImage@ healthBar;
BorderImage@ sight;

Controls playerControls;
bool paused = false;
bool gameOn = false;

void start()
{
    initAudio();
    initConsole();
    initScene();
    createCamera();
    createOverlays();
    startGame();

    subscribeToEvent("Update", "handleUpdate");
    subscribeToEvent("PostUpdate", "handlePostUpdate");
    subscribeToEvent("KeyDown", "handleKeyDown");
    subscribeToEvent("WindowResized", "handleWindowResized");
}

void runFrame()
{
    engine.runFrame(gameScene, gameCamera, !paused);

    if (input.getKeyPress(KEY_ESCAPE))
        engine.exit();
}

void initAudio()
{
    // Lower mastervolumes slightly
    audio.setMasterGain(CHANNEL_MASTER, 0.75f);
    audio.setMasterGain(CHANNEL_MUSIC, 0.75f);

    // Start music playback
    Song@ song = cache.getResource("XM", "Music/NinjaGods.xm");
    song.play(0);
}

void initConsole()
{
    if (engine.isHeadless())
        return;

    Console@ console = engine.createConsole();
    console.setNumRows(16);
    console.setFont(cache.getResource("Font", "cour.ttf"), 12);
    BorderImage@ cursor = console.getLineEditElement().getCursorElement();
    cursor.setWidth(4);
    cursor.setTexture(cache.getResource("Texture2D", "Textures/UI.png"));
    cursor.setImageRect(112, 0, 116, 16);

    engine.createDebugHud();
    debugHud.setFont(cache.getResource("Font", "cour.ttf"), 12);
}

void initScene()
{
    @gameScene = engine.createScene("NinjaSnowWar", BoundingBox(-100000.0, 100000.0), 8, true);
    // Make the scene directly accessible from the console
    engine.setDefaultScene(gameScene);

    File@ levelFile = cache.getFile("TestLevel.xml");
    gameScene.loadXML(levelFile);
}

void createCamera()
{
    Entity@ cameraEntity = gameScene.createEntity("Camera");
    @gameCamera = cameraEntity.createComponent("Camera");
    if (!engine.isHeadless())
        gameCamera.setAspectRatio(float(renderer.getWidth()) / float(renderer.getHeight()));
    gameCamera.setNearClip(10.0);
    gameCamera.setFarClip(16000.0);
    gameCamera.setPosition(Vector3(0, 200, -1000));
}

void createOverlays()
{
    if (engine.isHeadless())
        return;

    int height = renderer.getHeight() / 22;
    if (height > 64)
        height = 64;

    @sight = BorderImage();
    sight.setTexture(cache.getResource("Texture2D", "Textures/Sight.png"));
    sight.setAlignment(HA_CENTER, VA_CENTER);
    sight.setSize(height, height);
    uiRoot.addChild(sight);

    Font@ font = cache.getResource("Font", "Fonts/BlueHighway.ttf");

    @scoreText = Text();
    scoreText.setFont(font, 17);
    scoreText.setAlignment(HA_LEFT, VA_TOP);
    scoreText.setPosition(5, 5);
    scoreText.setColor(C_BOTTOMLEFT, Color(1, 1, 0.25));
    scoreText.setColor(C_BOTTOMRIGHT, Color(1, 1, 0.25));
    uiRoot.addChild(scoreText);

    @hiscoreText = Text();
    hiscoreText.setFont(font, 17);
    hiscoreText.setAlignment(HA_RIGHT, VA_TOP);
    hiscoreText.setPosition(-5, 5);
    hiscoreText.setColor(C_BOTTOMLEFT, Color(1, 1, 0.25));
    hiscoreText.setColor(C_BOTTOMRIGHT, Color(1, 1, 0.25));
    uiRoot.addChild(hiscoreText);

    @messageText = Text();
    messageText.setFont(font, 17);
    messageText.setColor(Color(1, 0, 0));
    messageText.setAlignment(HA_CENTER, VA_CENTER);
    messageText.setPosition(0, -height * 2);
    uiRoot.addChild(messageText);

    BorderImage@ healthBorder = BorderImage();
    healthBorder.setTexture(cache.getResource("Texture2D", "Textures/HealthBarBorder.png"));
    healthBorder.setAlignment(HA_CENTER, VA_TOP);
    healthBorder.setPosition(0, 8);
    healthBorder.setSize(120, 20);
    uiRoot.addChild(healthBorder);

    @healthBar = BorderImage();
    healthBar.setTexture(cache.getResource("Texture2D", "Textures/HealthBarInside.png"));
    healthBar.setPosition(2, 2);
    healthBar.setSize(116, 16);
    healthBorder.addChild(healthBar);
    uiRoot.addChild(healthBorder);
}

void startGame()
{
    // Clear the scene of all existing scripted entities
    array<Entity@> scriptedEntities = gameScene.getScriptedEntities();
    for (int i = 0; i < scriptedEntities.length(); ++i)
        gameScene.removeEntity(scriptedEntities[i]);

    Entity@ playerEntity = gameScene.createEntity("Player");
    ScriptInstance@ instance = playerEntity.createComponent("ScriptInstance");
    instance.setScriptClass(cache.getResource("ScriptFile", "Scripts/NinjaSnowWar.as"), "Ninja");
    GameObject@ object = cast<GameObject>(instance.getScriptObject());
    object.create(Vector3(0, 90, 0), Quaternion());
    object.health = object.maxHealth = playerHealth;
    object.side = SIDE_PLAYER;

    gameOn = true;
}

void handleUpdate(StringHash eventType, VariantMap& eventData)
{
    if (input.getKeyPress(KEY_F1))
        debugHud.toggleAll();
    if (input.getKeyPress(KEY_F2))
        engine.setDebugDrawMode(engine.getDebugDrawMode() ^ DEBUGDRAW_PHYSICS);

    if ((!console.isVisible()) && (input.getKeyPress('P')))
    {
        paused = !paused;
        if (paused)
            messageText.setText("PAUSED");
        else
            messageText.setText("");
    }

    if (!paused)
        updateControls();
}

void handlePostUpdate(StringHash eventType, VariantMap& eventData)
{
    updateCamera();
    updateStatus();
}

void updateControls()
{
    playerControls.set(CTRL_ALL, false);

    Entity@ playerEntity = gameScene.getEntity("Player");
    if (@playerEntity == null)
        return;

    if (!console.isVisible())
    {
        if (input.getKeyDown('W'))
            playerControls.set(CTRL_UP, true);
        if (input.getKeyDown('S'))
            playerControls.set(CTRL_DOWN, true);
        if (input.getKeyDown('A'))
            playerControls.set(CTRL_LEFT, true);
        if (input.getKeyDown('D'))
            playerControls.set(CTRL_RIGHT, true);
        if (input.getKeyDown(KEY_CONTROL))
            playerControls.set(CTRL_FIRE, true);
        if (input.getKeyDown(' '))
            playerControls.set(CTRL_JUMP, true);
    }

    if (input.getMouseButtonDown(MOUSEB_LEFT))
        playerControls.set(CTRL_FIRE, true);
    if (input.getMouseButtonDown(MOUSEB_RIGHT))
        playerControls.set(CTRL_JUMP, true);

    playerControls.yaw += mouseSensitivity * input.getMouseMoveX();
    playerControls.pitch += mouseSensitivity * input.getMouseMoveY();
    playerControls.pitch = clamp(playerControls.pitch, -60, 60);

    GameObject@ object = cast<GameObject>(playerEntity.getScriptObject());
    object.setControls(playerControls);
    
    if ((input.getKeyPress('K')) && (object.health > 0))
        object.health = object.health - 1;
}

void updateCamera()
{
    Entity@ playerEntity = gameScene.getEntity("Player");
    if (@playerEntity == null)
        return;

    RigidBody@ body = playerEntity.getComponent("RigidBody");
    Vector3 pos = body.getWorldPosition();
    Quaternion dir;
    dir = dir * Quaternion(playerControls.yaw, Vector3(0, 1, 0));
    dir = dir * Quaternion(playerControls.pitch, Vector3(1, 0, 0));

    Vector3 aimPoint = pos + Vector3(0, 100, 0);
    Vector3 minDist = aimPoint + dir * Vector3(0, 0, -cameraMinDist);
    Vector3 maxDist = aimPoint + dir * Vector3(0, 0, -cameraMaxDist);

    // Collide camera ray with static objects (collision mask 2)
    Vector3 rayDir = (maxDist - minDist).getNormalized();
    float rayDistance = cameraMaxDist - cameraMinDist + cameraSafetyDist;
    array<PhysicsRaycastResult>@ result = gameScene.getPhysicsWorld().raycast(Ray(minDist, rayDir), rayDistance, 2);
    if (result.length() > 0)
        rayDistance = min(rayDistance, result[0].distance - cameraSafetyDist);

    gameCamera.setPosition(minDist + rayDir * rayDistance);
    gameCamera.setRotation(dir);

    audio.setListenerPosition(pos);
    audio.setListenerRotation(dir);
}

void updateStatus()
{
    if (engine.isHeadless())
        return;

    Entity@ playerEntity = gameScene.getEntity("Player");
    if (@playerEntity == null)
        return;

    GameObject@ object = cast<GameObject>(playerEntity.getScriptObject());
    healthBar.setWidth(116 * object.health / playerHealth);
}

void handleKeyDown(StringHash eventType, VariantMap& eventData)
{
    // Check for toggling the console
    if (eventData["Key"].getInt() == 220)
    {
        console.toggle();
        input.suppressNextChar();
    }
}

void handleWindowResized(StringHash eventType, VariantMap& eventData)
{
    gameCamera.setAspectRatio(float(renderer.getWidth()) / float(renderer.getHeight()));
    
    int height = renderer.getHeight() / 22;
    if (height > 64)
        height = 64;
    sight.setSize(height, height);
    messageText.setPosition(0, -height * 2);
}

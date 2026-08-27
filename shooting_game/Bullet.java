import greenfoot.*;  // (World, Actor, GreenfootImage, Greenfoot and MouseInfo)


public class Bullet extends Actor
{
    /**
     * Act - do whatever the Bullet wants to do. 
     * This method is called whenever the 'Act' or 'Run' button gets pressed 
     * in the environment.
     */
    public void act()
    {
        // Move the bullet forward
        move(6);

        // Check if the bullet is out of the game world and remove it
        World world = getWorld();
        if (getX() < 0 || getX() >= world.getWidth() ||
            getY() < 0 || getY() >= world.getHeight()) {
            world.removeObject(this);
            return;
        }

        // Check if the bullet hits a rock
        if (!getObjectsInRange(20, Rock.class).isEmpty()) {
            
            Rock rock = (Rock) getObjectsInRange(20, Rock.class).get(0);

            getWorld().removeObject(rock);

            Score score = (Score) getWorld().getObjects(Score.class).get(0);
            score.increase();
            
            getWorld().removeObject(this);

            return;
        }
    }
}